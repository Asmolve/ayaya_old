require "application_system_test_case"

class DiaryCalendarTest < ApplicationSystemTestCase
  teardown { page.execute_script("localStorage.clear()") if page.current_url.start_with?("http") }

  test "clicking a day opens a matching one-day modal" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    find('[data-date="2026-09-07"]').click

    assert_selector "#diary-modal.is-open"
    assert_equal "2026-09-07", find("#note_start_date").value
    assert_equal "2026-09-07", find("#note_end_date").value
  end

  test "dragging across cells chooses both inclusive boundaries" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    find('[data-date="2026-09-07"]').drag_to(find('[data-date="2026-09-11"]'))

    assert_selector "#diary-modal.is-open"
    assert_equal "2026-09-07", find("#note_start_date").value
    assert_equal "2026-09-11", find("#note_end_date").value
  end

  test "clicking an ISO week number selects its full Monday-to-Sunday range" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    find('[data-range-start="2026-09-07"][data-range-end="2026-09-13"]', match: :first).click

    assert_selector "#diary-modal.is-open"
    assert_equal "2026-09-07", find("#note_start_date").value
    assert_equal "2026-09-13", find("#note_end_date").value
  end

  test "clicking a month name selects its full calendar month" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    find('[data-range-start="2026-08-01"][data-range-end="2026-08-31"]', match: :first).click

    assert_selector "#diary-modal.is-open"
    assert_equal "2026-08-01", find("#note_start_date").value
    assert_equal "2026-08-31", find("#note_end_date").value
  end

  test "opening an exact existing range populates its diary entry" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    owner = LocalUser.find_by!(core_user_id: "1")
    Note.create!(local_user: owner, title: "Saved entry", entry_type: :diary,
                 start_date: "2026-09-07", end_date: "2026-09-07", diary_content: "Saved body")

    visit "/m/notes/diary?quarter=2026-09-01"
    find('[data-date="2026-09-07"]').click

    assert_equal "Saved entry", find("#note_title").value
    assert_equal "Saved body", page.evaluate_script("document.querySelector('trix-editor').editor.getDocument().toString()").strip
  end

  test "opening a range restores its unexpired matching draft" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    key = draft_key("2026-09-07", "2026-09-07")
    write_draft(key, title: "Unsent entry", content: "Unsent body", expires_at: 1.hour.from_now.to_i * 1000)

    find('[data-date="2026-09-07"]').click

    assert_equal "Unsent entry", find("#note_title").value
    assert_equal "Unsent body", page.evaluate_script("document.querySelector('trix-editor').editor.getDocument().toString()").strip
  end

  test "opening a range discards an expired matching draft" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    key = draft_key("2026-09-07", "2026-09-07")
    write_draft(key, title: "Stale entry", content: "Stale body", expires_at: 1.hour.ago.to_i * 1000)

    find('[data-date="2026-09-07"]').click

    assert_equal "", find("#note_title").value
    assert_nil page.evaluate_script("localStorage.getItem(arguments[0])", key)
  end

  test "drafts are stored after editing" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    find('[data-date="2026-09-07"]').click
    fill_in "Title", with: "Draft title"

    assert_selector "#diary-modal.is-open"
    assert_draft_value draft_key("2026-09-07", "2026-09-07"), "title", "Draft title"
  end

  test "a successful save clears the matching draft" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    key = draft_key("2026-09-07", "2026-09-07")
    find('[data-date="2026-09-07"]').click
    fill_in "Title", with: "Saved from draft"
    stored_draft(key)

    click_on "Save"

    assert_no_selector "#diary-modal.is-open"
    assert_nil page.evaluate_script("localStorage.getItem(arguments[0])", key)
    assert_equal 1, Note.where(title: "Saved from draft").count
  end

  test "a successful delete clears the matching draft" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    owner = LocalUser.find_by!(core_user_id: "1")
    note = Note.create!(local_user: owner, title: "Delete me", entry_type: :diary,
                        start_date: "2026-09-07", end_date: "2026-09-07")
    key = draft_key("2026-09-07", "2026-09-07")
    write_draft(key, title: "Delete me", content: "", expires_at: 1.hour.from_now.to_i * 1000)

    visit "/m/notes/diary?quarter=2026-09-01"
    find('[data-date="2026-09-07"]').click
    find("[data-diary-delete]").click

    assert_no_selector "#diary-modal.is-open"
    assert_nil page.evaluate_script("localStorage.getItem(arguments[0])", key)
    assert_nil Note.find_by(id: note.id)
  end

  private

  def draft_key(start_date, end_date)
    "diary-draft-v1:#{find('[data-diary-calendar]')['data-local-user-id']}:#{start_date}:#{end_date}"
  end

  def write_draft(key, title:, content:, expires_at:)
    payload = { title:, content:, start_date: "2026-09-07", end_date: "2026-09-07", expires_at: }.to_json
    page.execute_script("localStorage.setItem(arguments[0], arguments[1])", key, payload)
  end

  def assert_draft_value(key, field, expected)
    assert_equal expected, stored_draft(key).fetch(field)
  end

  def stored_draft(key)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      raw = page.evaluate_script("localStorage.getItem(arguments[0])", key)
      return JSON.parse(raw) if raw.present?

      raise "Timed out waiting for a diary draft" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end
  end
end
