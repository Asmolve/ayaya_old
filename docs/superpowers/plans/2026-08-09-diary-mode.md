# Diary Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a rich, date-range Diary mode to the Notes module while preserving ordinary Notes.

**Architecture:** Extend `Note` with an entry type and inclusive date boundaries rather than introduce a second record type. Rails Action Text and Active Storage own rich content and embedded media; a dedicated Diary controller renders the quarter and resolves exact ranges. A small browser controller handles calendar selection, modal animation, and expiring drafts.

**Tech Stack:** Rails 8.1, PostgreSQL, Action Text/Trix, Active Storage, Propshaft, importmap-rails, Minitest, vanilla JavaScript.

## Global Constraints

- Ordinary Notes retain their current title/body editing and routes.
- Diary ranges are inclusive and are stored as `start_date` and `end_date`.
- An authenticated user may have only one Diary entry for an exact range; partial overlaps are allowed.
- All record access remains scoped through `current_local_user`.
- The calendar displays three months per navigable quarter and starts weeks on Monday.
- Draft cache data expires after exactly 24 hours and never stores binary files.

---

## File Structure

- `modules/notes/app/db/migrate/20260809000000_add_diary_fields_to_notes.rb` — adds Diary type/date fields and the exact-range unique index.
- `modules/notes/app/db/migrate/20260809000001_create_active_storage_tables.active_storage.rb` — Active Storage tables.
- `modules/notes/app/db/migrate/20260809000002_create_action_text_tables.action_text.rb` — Action Text rich-text table.
- `modules/notes/app/app/models/note.rb` — type/range validation and rich Diary association.
- `modules/notes/app/app/controllers/diary_controller.rb` — quarter rendering and exact-range lookup.
- `modules/notes/app/app/helpers/diary_helper.rb` — date-range and quarter helpers.
- `modules/notes/app/app/views/diary/index.html.erb` — calendar and editor modal.
- `modules/notes/app/app/javascript/diary_calendar.js` — pointer interaction and cache.
- `modules/notes/app/test/models/note_test.rb`, `test/controllers/diary_controller_test.rb`, `test/controllers/notes_controller_test.rb`, `test/helpers/diary_helper_test.rb`, `test/system/diary_calendar_test.rb` — automated coverage.

## Task 1: Add Diary persistence and rich-content infrastructure

**Files:**
- Create: `modules/notes/app/db/migrate/20260809000000_add_diary_fields_to_notes.rb`
- Create: `modules/notes/app/db/migrate/20260809000001_create_active_storage_tables.active_storage.rb`
- Create: `modules/notes/app/db/migrate/20260809000002_create_action_text_tables.action_text.rb`
- Modify: `modules/notes/app/Gemfile`, `Gemfile.lock`, `config/application.rb`, `app/models/note.rb`
- Test: `modules/notes/app/test/models/note_test.rb`

**Interfaces:**
- Consumes: existing `Note#local_user`.
- Produces: `Note.regular`, `Note.diary`, `note.diary?`, and `note.diary_content`.

- [ ] **Step 1: Write the failing model tests**

```ruby
test "diary requires an ordered inclusive range and allows a partial overlap" do
  user = LocalUser.create!(core_user_id: "diary-owner")
  Note.create!(local_user: user, title: "Week", entry_type: :diary,
               start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 13))
  overlap = Note.new(local_user: user, title: "Overlap", entry_type: :diary,
                     start_date: Date.new(2026, 9, 10), end_date: Date.new(2026, 9, 15))
  reversed = Note.new(local_user: user, title: "Bad", entry_type: :diary,
                      start_date: Date.new(2026, 9, 13), end_date: Date.new(2026, 9, 7))

  assert_predicate overlap, :valid?
  assert_not reversed.valid?
end

test "diary rejects an exact range duplicate for the same user" do
  user = LocalUser.create!(core_user_id: "duplicate-owner")
  attrs = { local_user: user, title: "Day", entry_type: :diary,
            start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7) }
  Note.create!(attrs)
  duplicate = Note.new(attrs)

  assert_not duplicate.valid?
  assert_includes duplicate.errors[:start_date], "has already been taken for this range"
end
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `cd modules/notes/app && bin/rails test test/models/note_test.rb`

Expected: FAIL because `entry_type`, range boundaries, and `diary?` do not exist.

- [ ] **Step 3: Implement the minimal persistence layer**

```ruby
# migration
add_column :notes, :entry_type, :string, null: false, default: "regular"
add_column :notes, :start_date, :date
add_column :notes, :end_date, :date
add_index :notes, %i[local_user_id start_date end_date], unique: true,
          where: "entry_type = 'diary'", name: "index_notes_on_user_and_diary_range"

# note.rb
enum :entry_type, { regular: "regular", diary: "diary" }, default: :regular
has_rich_text :diary_content
validates :start_date, :end_date, presence: true, if: :diary?
validate :diary_dates_are_in_order
validates :start_date, uniqueness: { scope: %i[local_user_id end_date],
  message: "has already been taken for this range" }, if: :diary?
```

Enable `active_storage/engine` and `action_text/engine`. Add `importmap-rails`, install the standard Trix pins, and create the standard Active Storage and Action Text tables in the named migrations. Preserve `body` for regular Notes.

- [ ] **Step 4: Migrate and verify the focused tests pass**

Run: `cd modules/notes/app && bin/rails db:migrate RAILS_ENV=test && bin/rails test test/models/note_test.rb`

Expected: PASS for ordinary Notes, range validation, exact-range rejection, and partial overlap.

- [ ] **Step 5: Commit**

```bash
git add modules/notes/app/Gemfile modules/notes/app/Gemfile.lock modules/notes/app/config/application.rb modules/notes/app/db/migrate/20260809000000_add_diary_fields_to_notes.rb modules/notes/app/db/migrate/20260809000001_create_active_storage_tables.active_storage.rb modules/notes/app/db/migrate/20260809000002_create_action_text_tables.action_text.rb modules/notes/app/app/models/note.rb modules/notes/app/test/models/note_test.rb
git commit -m "Add diary note persistence"
```

## Task 2: Add scoped Diary routes and date-range helpers

**Files:**
- Create: `modules/notes/app/app/controllers/diary_controller.rb`
- Create: `modules/notes/app/app/helpers/diary_helper.rb`
- Modify: `modules/notes/app/config/routes.rb`, `app/controllers/notes_controller.rb`
- Test: `modules/notes/app/test/controllers/diary_controller_test.rb`, `test/helpers/diary_helper_test.rb`, `test/controllers/notes_controller_test.rb`

**Interfaces:**
- Consumes: `Note.diary`, `current_local_user`, date fields from Task 1.
- Produces: `quarter_start(date)`, `range_for_iso_week(date)`, `range_for_month(date)`, `DiaryController#index`, and `DiaryController#entry`.

- [ ] **Step 1: Write failing helper/controller tests**

```ruby
test "normalizes week and month selections inclusively" do
  assert_equal Date.new(2026, 9, 7)..Date.new(2026, 9, 13), range_for_iso_week(Date.new(2026, 9, 10))
  assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), range_for_month(Date.new(2026, 9, 10))
end

test "returns only the current user's exact diary entry" do
  owner = LocalUser.create!(core_user_id: "1")
  entry = Note.create!(local_user: owner, title: "Mine", entry_type: :diary,
    start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 7))
  get "/m/notes/diary/entry", params: { start_date: "2026-09-07", end_date: "2026-09-07" }, headers: ayaya_headers

  assert_response :success
  assert_equal entry.id, response.parsed_body.fetch("id")
end
```

- [ ] **Step 2: Run and verify failure**

Run: `cd modules/notes/app && bin/rails test test/helpers/diary_helper_test.rb test/controllers/diary_controller_test.rb`

Expected: FAIL because routes, helpers, and the controller do not exist.

- [ ] **Step 3: Implement scoped endpoints**

```ruby
# routes.rb, inside scope "/m/notes"
get "diary", to: "diary#index", as: :diary
get "diary/entry", to: "diary#entry", defaults: { format: :json }

# diary_controller.rb
def entry
  entry = current_local_user.notes.diary.find_by!(
    start_date: params.require(:start_date), end_date: params.require(:end_date)
  )
  render json: { id: entry.id, title: entry.title, start_date: entry.start_date,
                 end_date: entry.end_date, content: entry.diary_content.to_s }
rescue ActiveRecord::RecordNotFound
  render json: { id: nil }, status: :not_found
end
```

Parse the optional quarter parameter as an ISO date, normalize it to the quarter's first month, and return `422` for invalid input. Permit `entry_type`, `start_date`, `end_date`, and `diary_content` only in Diary saves. Do not allow a regular Note to become Diary through a forged update.

- [ ] **Step 4: Verify focused tests pass**

Run: `cd modules/notes/app && bin/rails test test/helpers/diary_helper_test.rb test/controllers/diary_controller_test.rb test/controllers/notes_controller_test.rb`

Expected: PASS for normalization, invalid parameters, ownership, exact match, and date updates.

- [ ] **Step 5: Commit**

```bash
git add modules/notes/app/config/routes.rb modules/notes/app/app/controllers/diary_controller.rb modules/notes/app/app/controllers/notes_controller.rb modules/notes/app/app/helpers/diary_helper.rb modules/notes/app/test/controllers/diary_controller_test.rb modules/notes/app/test/helpers/diary_helper_test.rb modules/notes/app/test/controllers/notes_controller_test.rb
git commit -m "Add diary calendar server endpoints"
```

## Task 3: Render three-month Diary UI and Action Text editor

**Files:**
- Create: `modules/notes/app/app/views/diary/index.html.erb`, `app/assets/stylesheets/actiontext.css`, `app/javascript/application.js`
- Modify: `app/views/layouts/application.html.erb`, `app/views/notes/index.html.erb`, `app/views/notes/show.html.erb`, `app/assets/stylesheets/application.css`, `config/importmap.rb`
- Test: `modules/notes/app/test/controllers/diary_controller_test.rb`, `test/controllers/notes_controller_test.rb`

**Interfaces:**
- Consumes: quarter data and routes from Task 2 plus Trix from Task 1.
- Produces: `data-diary-calendar`, `data-entry-lookup-url`, `data-local-user-id`, `#diary-modal`, and `#diary-form` for Task 4.

- [ ] **Step 1: Write failing rendering tests**

```ruby
test "renders a three-month calendar and modal hooks" do
  get "/m/notes/diary?quarter=2026-09-01", headers: ayaya_headers

  assert_response :success
  %w[Июль Август Сентябрь].each { |name| assert_includes response.body, name }
  assert_includes response.body, "data-diary-calendar"
  assert_includes response.body, 'id="diary-modal"'
end

test "labels diary records with their inclusive dates in Notes" do
  user = LocalUser.create!(core_user_id: "1")
  Note.create!(local_user: user, title: "Trip", entry_type: :diary,
    start_date: Date.new(2026, 9, 7), end_date: Date.new(2026, 9, 11))
  get "/m/notes", headers: ayaya_headers

  assert_includes response.body, "Trip · 07.09.2026 — 11.09.2026"
end
```

- [ ] **Step 2: Run and verify failure**

Run: `cd modules/notes/app && bin/rails test test/controllers/diary_controller_test.rb test/controllers/notes_controller_test.rb`

Expected: FAIL because the template and Diary labels do not exist.

- [ ] **Step 3: Implement templates and assets**

```erb
<nav class="notes-mode-nav" aria-label="Notes mode">
  <%= link_to "Notes", notes_root_path %>
  <%= link_to "Diary", diary_path, aria: { current: "page" } %>
</nav>

<section data-diary-calendar data-entry-lookup-url="<%= diary_entry_path %>"
  data-local-user-id="<%= current_local_user.id %>">
  <% @months.each do |month| %>
    <button type="button" class="diary-month-name"
      data-range-start="<%= month.beginning_of_month %>"
      data-range-end="<%= month.end_of_month %>"><%= l(month, format: "%B") %></button>
  <% end %>
</section>
```

Add `javascript_importmap_tags` to the layout, import and pin `trix`, `@rails/actiontext`, and `diary_calendar`, and render `form.rich_text_area :diary_content` in the modal. Show `@note.diary_content` for Diary and keep `simple_format(@note.body)` for regular Notes. CSS must make three desktop columns, one narrow-screen column, red weekends, visible focus rings, and opacity/transform transitions on `.is-open`.

- [ ] **Step 4: Verify rendering tests pass**

Run: `cd modules/notes/app && bin/rails test test/controllers/diary_controller_test.rb test/controllers/notes_controller_test.rb`

Expected: PASS with calendar markup, editor/modal hooks, navigation, and inclusive list labels.

- [ ] **Step 5: Commit**

```bash
git add modules/notes/app/app/views/diary/index.html.erb modules/notes/app/app/views/layouts/application.html.erb modules/notes/app/app/views/notes/index.html.erb modules/notes/app/app/views/notes/show.html.erb modules/notes/app/app/assets/stylesheets/application.css modules/notes/app/app/assets/stylesheets/actiontext.css modules/notes/app/config/importmap.rb modules/notes/app/app/javascript/application.js modules/notes/app/test/controllers/diary_controller_test.rb modules/notes/app/test/controllers/notes_controller_test.rb
git commit -m "Render diary calendar and editor"
```

## Task 4: Add selection, modal behaviour, and 24-hour drafts

**Files:**
- Create: `modules/notes/app/app/javascript/diary_calendar.js`
- Modify: `modules/notes/app/app/views/diary/index.html.erb`, `app/assets/stylesheets/application.css`
- Create: `modules/notes/app/test/system/diary_calendar_test.rb`

**Interfaces:**
- Consumes: Task 3 DOM hooks and Task 2 lookup endpoint.
- Produces: a `DiaryCalendar` controller and `diary-draft-v1:<user>:<start>:<end>` localStorage records.

- [ ] **Step 1: Write failing system tests**

```ruby
test "clicking a day opens a matching one-day modal" do
  visit "/m/notes/diary?quarter=2026-09-01", headers: ayaya_headers
  find('[data-date="2026-09-07"]').click

  assert_selector "#diary-modal.is-open"
  assert_equal "2026-09-07", find("#note_start_date").value
  assert_equal "2026-09-07", find("#note_end_date").value
end

test "dragging across cells chooses both inclusive boundaries" do
  visit "/m/notes/diary?quarter=2026-09-01", headers: ayaya_headers
  find('[data-date="2026-09-07"]').drag_to(find('[data-date="2026-09-11"]'))

  assert_equal "2026-09-07", find("#note_start_date").value
  assert_equal "2026-09-11", find("#note_end_date").value
end
```

- [ ] **Step 2: Run and verify failure**

Run: `cd modules/notes/app && bin/rails test test/system/diary_calendar_test.rb`

Expected: FAIL because date cells do not have pointer handlers or open the modal.

- [ ] **Step 3: Implement browser behaviour**

```javascript
const normalizeRange = (left, right) => left <= right ? [left, right] : [right, left]
const draftKey = (userId, start, end) => `diary-draft-v1:${userId}:${start}:${end}`
const expiresAt = () => Date.now() + 24 * 60 * 60 * 1000

calendar.addEventListener("pointerup", (event) => {
  if (!dragStart) return
  const end = event.target.closest("[data-date]")?.dataset.date || dragStart
  openRange(...normalizeRange(dragStart, end))
  dragStart = null
})
```

Handle `pointerdown`, `pointerenter`, `pointerup`, and `pointercancel`; capture the pointer so touch releases resolve. Use direct handlers for week and month boundary data. `openRange` fetches the exact entry, resets or populates the form, restores only an unexpired matching draft, and adds `.is-open`. Debounce localStorage writes for title, dates, and editor HTML. Never serialize files. Clear a draft only after successful save or delete.

- [ ] **Step 4: Verify system and module tests pass**

Run: `cd modules/notes/app && bin/rails test test/system/diary_calendar_test.rb && bin/rails test`

Expected: PASS for day/week/month/drag selection, modal lifecycle, exact-range edit, expiry/restore, deletion, and existing Notes tests.

- [ ] **Step 5: Commit**

```bash
git add modules/notes/app/app/javascript/diary_calendar.js modules/notes/app/app/views/diary/index.html.erb modules/notes/app/app/assets/stylesheets/application.css modules/notes/app/test/system/diary_calendar_test.rb
git commit -m "Add interactive diary calendar"
```

## Task 5: Verify end-to-end integration and refresh the graph

**Files:**
- Modify: `modules/notes/app/db/schema.rb`
- Modify: `graphify-out/` generated output only if `graphify update .` changes it.

**Interfaces:**
- Consumes: the completed data, server, template, and browser layers.
- Produces: migrated schema and a current project graph.

- [ ] **Step 1: Run module verification**

Run: `cd modules/notes/app && bin/rails db:migrate && bin/rails test && bin/rails runner 'puts Note.diary.count'`

Expected: migrations complete, all tests pass, and the runner exits successfully.

- [ ] **Step 2: Perform the manual user flow**

Open Diary through the Notes adapter with Ayaya identity headers. Create a day entry, reopen it, change it to a week, create a partially overlapping entry, embed a small image in Trix, delete one entry, and verify the Notes list labels the remaining Diary entry with its inclusive range.

- [ ] **Step 3: Refresh the graph**

Run: `graphify update .`

Expected: the AST-based update succeeds. Retain only graph files resulting from Diary implementation.

- [ ] **Step 4: Commit generated integration output when changed**

```bash
git add modules/notes/app/db/schema.rb graphify-out
git commit -m "Update diary schema and project graph"
```

