require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  def ayaya_headers(core_user_id: "1", email: "user@example.test")
    {
      "X-Ayaya-User-Id" => core_user_id,
      "X-Ayaya-User-Email" => email,
      "X-Ayaya-User-Display-Name" => "User #{core_user_id}",
      "X-Ayaya-User-Role" => "user",
      "X-Ayaya-Module-Key" => "notes"
    }
  end

  test "shows empty state and new note link for a user without notes" do
    get "/m/notes", headers: ayaya_headers(core_user_id: "1")

    assert_response :success
    assert_includes response.body, "No notes yet"
    assert_includes response.body, "New note"
  end

  test "lists only current user's notes" do
    owner = LocalUser.create!(core_user_id: "1")
    other = LocalUser.create!(core_user_id: "2")
    Note.create!(local_user: owner, title: "Mine", body: "Visible")
    Note.create!(local_user: other, title: "Other", body: "Hidden")

    get "/m/notes", headers: ayaya_headers(core_user_id: "1")

    assert_response :success
    assert_includes response.body, "Mine"
    assert_not_includes response.body, "Other"
  end

  test "labels diary records with their inclusive dates in Notes" do
    user = LocalUser.create!(core_user_id: "1")
    Note.create!(local_user: user, title: "Trip", entry_type: :diary,
                 start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 11))

    get "/m/notes", headers: ayaya_headers

    assert_includes response.body, "Trip"
    assert_includes response.body, "07.09.2026 — 11.09.2026"
  end

  test "creates note owned by current local user" do
    assert_difference("Note.count", 1) do
      post "/m/notes/notes", params: { note: { title: "New note", body: "Body" } }, headers: ayaya_headers(core_user_id: "1")
    end

    note = Note.last
    assert_equal "1", note.local_user.core_user_id
    assert_redirected_to "/m/notes/notes/#{note.id}"
  end

  test "creates a diary entry with its inclusive range and rich content" do
    assert_difference("Note.diary.count", 1) do
      post "/m/notes/notes", params: { note: {
        title: "Day", entry_type: "diary", start_date: "2026-09-07", end_date: "2026-09-07",
        diary_content: "<div>Remember this</div>"
      } }, headers: ayaya_headers(core_user_id: "1")
    end

    entry = Note.last
    assert_predicate entry, :diary?
    assert_equal Date.new(2026, 9, 7), entry.start_date
    assert_equal Date.new(2026, 9, 7), entry.end_date
    assert_includes entry.diary_content.to_s, "Remember this"
  end

  test "returns a range validation error when a diary create loses the unique-index race" do
    with_diary_unique_index_conflict do
      post "/m/notes/notes", params: { note: {
        title: "Day", entry_type: "diary", start_date: "2026-09-07", end_date: "2026-09-07"
      } }, headers: ayaya_headers
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Start date has already been taken for this range"
  end

  test "does not show another user's note" do
    other = LocalUser.create!(core_user_id: "2")
    note = Note.create!(local_user: other, title: "Other", body: "Hidden")

    get "/m/notes/notes/#{note.id}", headers: ayaya_headers(core_user_id: "1")

    assert_response :not_found
  end

  test "updates only own note" do
    owner = LocalUser.create!(core_user_id: "1")
    note = Note.create!(local_user: owner, title: "Old", body: "Body")

    patch "/m/notes/notes/#{note.id}", params: { note: { title: "New", body: "Updated" } }, headers: ayaya_headers(core_user_id: "1")

    assert_redirected_to "/m/notes/notes/#{note.id}"
    assert_equal "New", note.reload.title
  end

  test "updates a diary entry's inclusive dates" do
    owner = LocalUser.create!(core_user_id: "1")
    entry = Note.create!(local_user: owner, title: "Week", entry_type: :diary,
                         start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7))

    patch "/m/notes/notes/#{entry.id}", params: { note: {
      title: "Longer week", start_date: "2026-09-07", end_date: "2026-09-13", diary_content: "Updated"
    } }, headers: ayaya_headers(core_user_id: "1")

    assert_redirected_to "/m/notes/notes/#{entry.id}"
    assert_equal [ Date.new(2026, 9, 7), Date.new(2026, 9, 13) ], entry.reload.attributes.values_at("start_date", "end_date")
    assert_includes entry.diary_content.to_s, "Updated"
  end

  test "returns a range validation error when a diary update loses the unique-index race" do
    owner = LocalUser.create!(core_user_id: "1")
    entry = Note.create!(local_user: owner, title: "Week", entry_type: :diary,
                         start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7))

    with_diary_unique_index_conflict do
      patch "/m/notes/notes/#{entry.id}", params: { note: {
        title: "Longer week", start_date: "2026-09-07", end_date: "2026-09-13"
      } }, headers: ayaya_headers
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Start date has already been taken for this range"
    assert_equal Date.new(2026, 9, 7), entry.reload.end_date
  end

  test "does not allow a regular note to become diary through an update" do
    owner = LocalUser.create!(core_user_id: "1")
    note = Note.create!(local_user: owner, title: "Regular", body: "Body")

    patch "/m/notes/notes/#{note.id}", params: { note: {
      entry_type: "diary", start_date: "2026-09-07", end_date: "2026-09-07", diary_content: "Forged"
    } }, headers: ayaya_headers(core_user_id: "1")

    assert_redirected_to "/m/notes/notes/#{note.id}"
    assert_predicate note.reload, :regular?
    assert_nil note.start_date
    assert_nil note.end_date
    assert_empty note.diary_content.to_s
  end

  test "does not delete another user's note" do
    other = LocalUser.create!(core_user_id: "2")
    note = Note.create!(local_user: other, title: "Other", body: "Hidden")

    assert_no_difference("Note.count") do
      delete "/m/notes/notes/#{note.id}", headers: ayaya_headers(core_user_id: "1")
    end

    assert_response :not_found
  end

  private

  def with_diary_unique_index_conflict
    original_save = Note.instance_method(:save)
    Note.define_method(:save) do |*args, **kwargs, &block|
      raise ActiveRecord::RecordNotUnique, "index_notes_on_user_and_diary_range" if diary?

      original_save.bind_call(self, *args, **kwargs, &block)
    end

    yield
  ensure
    Note.define_method(:save, original_save) if original_save
  end
end
