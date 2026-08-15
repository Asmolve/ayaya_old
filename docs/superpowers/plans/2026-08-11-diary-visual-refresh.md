# Diary Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a polished Diary UI whose assets load through the Notes route and whose responsive modal editor never overflows.

**Architecture:** Keep all behaviour in the existing Diary template/controller/JavaScript. Configure Propshaft with the Notes URL prefix; concentrate visual tokens and responsive layout in the existing stylesheet; verify routing through controller rendering and browser/system tests.

**Tech Stack:** Rails 8.1, Propshaft, importmap, Action Text/Trix, CSS, Minitest/Capybara.

## Global Constraints

- Serve Notes CSS and JavaScript under `/m/notes/assets`.
- Preserve existing Diary selection, modal, drafts, touch, save, delete, and rich-media behaviour.
- Toolbar never escapes the modal panel; narrow layouts scroll it horizontally.
- Desktop calendar has three rounded month cards; narrow screens use one column.

---

### Task 1: Route Notes assets through the module

**Files:**
- Modify: `modules/notes/app/config/application.rb`
- Modify: `modules/notes/app/test/controllers/diary_controller_test.rb`

**Interfaces:**
- Produces: Propshaft asset paths beginning `/m/notes/assets/`.

- [ ] **Step 1: Write the failing rendering test**

```ruby
test "Diary document links scoped Notes CSS and JavaScript assets" do
  get "/m/notes/diary", headers: ayaya_headers

  assert_includes response.body, "/m/notes/assets/"
end
```

- [ ] **Step 2: Verify RED**

Run: `cd modules/notes/app && bin/rails test test/controllers/diary_controller_test.rb`

Expected: FAIL because generated asset links use the unscoped `/assets/` prefix.

- [ ] **Step 3: Implement scoped asset prefix**

```ruby
# config/application.rb
config.assets.prefix = "/m/notes/assets"
```

- [ ] **Step 4: Verify GREEN**

Run: `cd modules/notes/app && bin/rails test test/controllers/diary_controller_test.rb && bin/rails test`

Expected: all controller and module tests pass.

- [ ] **Step 5: Commit**

```bash
git add modules/notes/app/config/application.rb modules/notes/app/test/controllers/diary_controller_test.rb
git commit -m "Route Notes assets through module"
```

### Task 2: Polish Diary navigation, calendar, and modal editor

**Files:**
- Modify: `modules/notes/app/app/views/diary/index.html.erb`
- Modify: `modules/notes/app/app/assets/stylesheets/application.css`
- Modify: `modules/notes/app/app/assets/stylesheets/actiontext.css`
- Modify: `modules/notes/app/test/system/diary_calendar_test.rb`

**Interfaces:**
- Consumes: existing `.diary-*` markup and modal data attributes.
- Produces: rounded visual system and overflow-safe `.trix-button-row` within `.diary-modal__panel`.

- [ ] **Step 1: Write the failing browser assertions**

```ruby
test "Diary modal keeps the editor toolbar within the panel on a narrow viewport" do
  page.driver.browser.manage.window.resize_to(390, 844)
  visit "/m/notes/diary", headers: ayaya_headers
  find('[data-date]').click

  assert_selector "#diary-modal.is-open .diary-modal__panel"
  assert_equal "auto", evaluate_script("getComputedStyle(document.querySelector('.trix-button-row')).overflowX")
end
```

- [ ] **Step 2: Verify RED**

Run: `cd modules/notes/app && bin/rails test test/system/diary_calendar_test.rb`

Expected: FAIL because the toolbar has no constrained overflow layout.

- [ ] **Step 3: Implement visual refresh**

Use rounded cards, responsive spacing, segmented navigation, circular calendar cells, visible selected range, and a modal flex layout. Set the panel to a bounded flex column; set `.trix-button-row` to `max-width: 100%`, `overflow-x: auto`, and `flex-wrap: nowrap`; ensure the editor shrinks within the panel and footer buttons stay inside it.

- [ ] **Step 4: Verify GREEN**

Run: `cd modules/notes/app && bin/rails test test/system/diary_calendar_test.rb && bin/rails test`

Expected: browser and module suites pass; toolbar remains inside the panel at 390px width.

- [ ] **Step 5: Commit**

```bash
git add modules/notes/app/app/views/diary/index.html.erb modules/notes/app/app/assets/stylesheets/application.css modules/notes/app/app/assets/stylesheets/actiontext.css modules/notes/app/test/system/diary_calendar_test.rb
git commit -m "Polish diary workspace"
```

