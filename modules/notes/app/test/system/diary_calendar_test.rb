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

  test "Diary modal keeps the editor toolbar within the panel on a narrow viewport" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    find('[data-date="2026-09-07"]').click

    assert_selector "#diary-modal.is-open .diary-modal__panel"
    assert_equal "auto", page.evaluate_script("getComputedStyle(document.querySelector('.trix-button-row')).overflowX")
  end

  test "dragging across cells chooses both inclusive boundaries" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    find('[data-date="2026-09-07"]').drag_to(find('[data-date="2026-09-11"]'))

    assert_selector "#diary-modal.is-open"
    assert_equal "2026-09-07", find("#note_start_date").value
    assert_equal "2026-09-11", find("#note_end_date").value
  end

  test "touch dragging reserves the selected dates and chooses both inclusive boundaries" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('[data-date=\"2026-09-07\"]')).touchAction")
    perform_touch_drag("2026-09-07", "2026-09-11")

    assert_selector "#diary-modal.is-open"
    assert_equal "2026-09-07", find("#note_start_date").value
    assert_equal "2026-09-11", find("#note_end_date").value
  end

  test "a canceled touch selection leaves the modal closed and does not poison the next touch selection" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"

    perform_touch_cancel("2026-09-07")
    assert_no_selector "#diary-modal.is-open"

    perform_touch_drag("2026-09-07", "2026-09-11")
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

    assert_input_value "#note_title", "Saved entry"
    assert_equal "Saved body", page.evaluate_script("document.querySelector('trix-editor').editor.getDocument().toString()").strip
  end

  test "a stale exact-range response cannot overwrite a newer selection" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    owner = LocalUser.find_by!(core_user_id: "1")
    Note.create!(local_user: owner, title: "Stale response", entry_type: :diary,
                 start_date: "2026-09-07", end_date: "2026-09-07")
    delay_exact_range_lookup("2026-09-07")

    find('[data-date="2026-09-07"]').click
    page.execute_script("arguments[0].click()", find('[data-date="2026-09-11"]').native)
    sleep 0.4

    assert_equal "2026-09-11", find("#note_start_date").value
    assert_equal "2026-09-11", find("#note_end_date").value
    assert_equal "", find("#note_title").value
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
    assert_draft_removed(key)
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

  test "saving an existing diary entry sends the CSRF token with its FormData request" do
    visit_as_ayaya_user "/m/notes/diary?quarter=2026-09-01"
    owner = LocalUser.find_by!(core_user_id: "1")
    note = Note.create!(local_user: owner, title: "Before update", entry_type: :diary,
                        start_date: "2026-09-07", end_date: "2026-09-07")

    visit "/m/notes/diary?quarter=2026-09-01"
    csrf_token = "csrf-regression-token"
    page.execute_script("const tag = document.createElement('meta'); tag.name = 'csrf-token'; tag.content = arguments[0]; document.head.append(tag)", csrf_token)
    capture_save_csrf_header
    find('[data-date="2026-09-07"]').click
    fill_in "Title", with: "After update"

    click_on "Save"

    assert_no_selector "#diary-modal.is-open"
    assert_equal "After update", note.reload.title
    assert_equal csrf_token, page.evaluate_script("localStorage.getItem('diary-save-csrf-header')")
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

  def assert_draft_removed(key)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      return if page.evaluate_script("localStorage.getItem(arguments[0])", key).nil?

      raise "Timed out waiting for an expired diary draft to be removed" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end
  end

  def assert_input_value(selector, expected)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      return if find(selector).value == expected

      raise "Timed out waiting for #{selector} to equal #{expected.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end
  end

  def perform_touch_drag(start_date, end_date)
    actions = page.driver.browser.action
    touch = actions.add_pointer_input(:touch, "diary-touch-drag")
    touch.create_pointer_move(origin: find("[data-date='#{start_date}']").native)
    touch.create_pointer_down(:touch)
    touch.create_pointer_move(duration: 0.2, origin: find("[data-date='#{end_date}']").native)
    touch.create_pointer_up(:touch)
    actions.perform
  end

  def capture_save_csrf_header
    page.execute_script(<<~JS)
      const originalFetch = window.fetch
      window.fetch = (input, options = {}) => {
        const url = new URL(input, window.location.origin)
        if (url.pathname.startsWith("/m/notes/notes/") && options.method === "POST") {
          localStorage.setItem("diary-save-csrf-header", new Headers(options.headers || {}).get("X-CSRF-Token") || "")
        }
        return originalFetch(input, options)
      }
    JS
  end

  def perform_touch_cancel(date)
    actions = page.driver.browser.action
    touch = actions.add_pointer_input(:touch, "diary-touch-cancel")
    touch.create_pointer_move(origin: find("[data-date='#{date}']").native)
    touch.create_pointer_down(:touch)
    touch.create_pointer_cancel
    actions.perform
  end

  def delay_exact_range_lookup(start_date)
    page.execute_script(<<~JS, start_date)
      const originalFetch = window.fetch
      window.fetch = (input, options) => {
        const url = new URL(input, window.location.origin)
        const response = originalFetch(input, options)
        if (url.pathname === "/m/notes/diary/entry" && url.searchParams.get("start_date") === arguments[0]) {
          return new Promise((resolve, reject) => window.setTimeout(() => response.then(resolve, reject), 250))
        }
        return response
      }
    JS
  end
end
