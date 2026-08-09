require "test_helper"

class DiaryControllerTest < ActionDispatch::IntegrationTest
  def ayaya_headers(core_user_id: "1")
    {
      "X-Ayaya-User-Id" => core_user_id,
      "X-Ayaya-Module-Key" => "notes"
    }
  end

  test "returns only the current user's exact diary entry" do
    owner = LocalUser.create!(core_user_id: "1")
    entry = Note.create!(local_user: owner, title: "Mine", entry_type: :diary,
                         start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7))
    entry.update!(diary_content: "<div>Diary body</div>")

    get "/m/notes/diary/entry", params: { start_date: "2026-09-07", end_date: "2026-09-07" }, headers: ayaya_headers

    assert_response :success
    assert_equal entry.id, response.parsed_body.fetch("id")
    assert_includes response.parsed_body.fetch("content"), "Diary body"
  end

  test "renders a three-month calendar and modal hooks" do
    get "/m/notes/diary?quarter=2026-09-01", headers: ayaya_headers

    assert_response :success
    %w[Июль Август Сентябрь].each { |name| assert_includes response.body, name }
    assert_includes response.body, "data-diary-calendar"
    assert_includes response.body, 'data-entry-lookup-url="/m/notes/diary/entry"'
    assert_includes response.body, 'data-local-user-id="'
    assert_includes response.body, 'id="diary-modal"'
    assert_includes response.body, 'id="diary-form"'
    assert_includes response.body, "trix-editor"
  end

  test "marks each visible day intersecting the current user's diary entries" do
    owner = LocalUser.create!(core_user_id: "1")
    Note.create!(local_user: owner, title: "Quarter boundary", entry_type: :diary,
                 start_date: Date.new(2026, 6, 30), end_date: Date.new(2026, 7, 2))
    Note.create!(local_user: owner, title: "September", entry_type: :diary,
                 start_date: Date.new(2026, 9, 29), end_date: Date.new(2026, 10, 2))

    get "/m/notes/diary?quarter=2026-09-01", headers: ayaya_headers

    assert_response :success
    assert_select '[data-date="2026-07-01"] .diary-entry-indicator', count: 1
    assert_select '[data-date="2026-07-02"] .diary-entry-indicator', count: 1
    assert_select '[data-date="2026-09-29"] .diary-entry-indicator', count: 1
    assert_select '[data-date="2026-09-30"] .diary-entry-indicator', count: 1
    assert_select '[data-date="2026-07-03"] .diary-entry-indicator', count: 0
  end

  test "does not mark another user's diary entries" do
    owner = LocalUser.create!(core_user_id: "1")
    other = LocalUser.create!(core_user_id: "2")
    Note.create!(local_user: owner, title: "Visible", entry_type: :diary,
                 start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7))
    Note.create!(local_user: other, title: "Private", entry_type: :diary,
                 start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 9))

    get "/m/notes/diary?quarter=2026-09-01", headers: ayaya_headers

    assert_response :success
    assert_select '[data-date="2026-09-07"] .diary-entry-indicator', count: 1
    assert_select '[data-date="2026-09-08"] .diary-entry-indicator', count: 0
    assert_select '[data-date="2026-09-09"] .diary-entry-indicator', count: 0
  end

  test "loads Action Text with the resolved Diary calendar module" do
    application_entrypoint = Rails.root.join("app/javascript/application.js").read
    importmap = Rails.root.join("config/importmap.rb").read

    assert_includes application_entrypoint, 'import "trix"'
    assert_includes application_entrypoint, 'import "@rails/actiontext"'
    assert_includes application_entrypoint, 'import "diary_calendar"'
    assert_includes importmap, 'pin "diary_calendar"'
  end

  test "does not return another user's diary entry" do
    owner = LocalUser.create!(core_user_id: "2")
    Note.create!(local_user: owner, title: "Private", entry_type: :diary,
                 start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7))

    get "/m/notes/diary/entry", params: { start_date: "2026-09-07", end_date: "2026-09-07" }, headers: ayaya_headers

    assert_response :not_found
    assert_nil response.parsed_body.fetch("id")
  end

  test "returns not found when a diary range is not an exact match" do
    owner = LocalUser.create!(core_user_id: "1")
    Note.create!(local_user: owner, title: "Week", entry_type: :diary,
                 start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 13))

    get "/m/notes/diary/entry", params: { start_date: "2026-09-08", end_date: "2026-09-08" }, headers: ayaya_headers

    assert_response :not_found
  end

  test "rejects invalid entry dates" do
    get "/m/notes/diary/entry", params: { start_date: "not-a-date", end_date: "2026-09-07" }, headers: ayaya_headers

    assert_response :unprocessable_entity
  end

  test "rejects non-scalar entry dates" do
    get "/m/notes/diary/entry", params: { start_date: [ "2026-09-07" ], end_date: "2026-09-07" }, headers: ayaya_headers

    assert_response :unprocessable_entity
  end

  test "rejects an invalid quarter date" do
    get "/m/notes/diary", params: { quarter: "not-a-date" }, headers: ayaya_headers

    assert_response :unprocessable_entity
  end

  test "rejects a non-scalar quarter date" do
    get "/m/notes/diary", params: { quarter: [ "2026-09-01" ] }, headers: ayaya_headers

    assert_response :unprocessable_entity
  end

  test "rejects empty structured date parameters" do
    [ [], {} ].each do |value|
      index_status = request_with_query_parameters("/m/notes/diary", { "quarter" => value })
      entry_status = request_with_query_parameters(
        "/m/notes/diary/entry", { "start_date" => value, "end_date" => "2026-09-07" }
      )

      assert_equal 422, index_status
      assert_equal 422, entry_status
    end
  end

  private

  def request_with_query_parameters(path, query_parameters)
    env = Rack::MockRequest.env_for(path, method: "GET")
    env["HTTP_USER_AGENT"] = ""
    env["action_dispatch.request.query_parameters"] = query_parameters
    ayaya_headers.each { |name, value| env["HTTP_#{name.upcase.tr('-', '_')}"] = value }

    status, = Rails.application.call(env)
    status
  end
end
