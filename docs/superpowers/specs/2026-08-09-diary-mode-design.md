# Diary Mode Design

## Goal

Add Diary as a distinct mode of the Notes module. Users create one rich diary entry for an exact, inclusive date range, using a three-month calendar. Ordinary Notes continue to work unchanged.

## Scope

- Add `Diary` beside the existing `Notes` mode.
- Show a navigable quarter: three adjacent months, Monday-first weekdays, ISO week numbers, and highlighted weekends.
- Select an inclusive range from a day, ISO week, month, or pointer/touch drag.
- Create or edit a Diary entry for the selected exact date range.
- Support a title, rich text, and media embedded at the editor cursor.
- Cache unsaved modal drafts in the browser for 24 hours.
- Include Diary entries in the Notes list as `Title · start date — end date`.

## Data Model

Diary entries use the existing `Note` model so ordinary Notes retain their current routes and data.

`notes` gains:

- `entry_type`, an enum with `regular` (the default) and `diary`.
- `start_date` and `end_date`, required for `diary` and absent for `regular`.

`Note` gains an Action Text rich-text association for Diary content. Its existing `body` remains the content field for ordinary Notes. Active Storage supports files embedded through Trix.

Validation requires a title for both types; requires valid inclusive dates for Diary; and prevents more than one entry for the same local user and exact Diary range. A database-level unique partial index on `(local_user_id, start_date, end_date)` for `entry_type = 'diary'` enforces that invariant under concurrent requests. Partially overlapping ranges remain valid.

## Routes and Server Behaviour

- `GET /m/notes/diary` renders the Diary calendar. The quarter is derived from an optional quarter-start parameter and defaults to the current quarter.
- A scoped endpoint resolves the current user's Diary entry by exact `start_date` and `end_date`; the calendar uses it to decide whether the modal is creating or editing.
- Diary creates, updates, and deletes use the existing Notes controller and ownership protections. Diary-specific parameters are permitted only for Diary entries.
- `GET /m/notes` remains the Notes list. It includes both kinds of record, ordered by recent update. Diary rows append their formatted inclusive range; ordinary rows retain their existing presentation.

## Calendar and Modal UX

The page follows the supplied calendar reference in a responsive application layout: three months in a desktop row and a single column on narrow screens. Each month shows its name, weekday headers, ISO week numbers, and six-or-fewer date rows. Quarter navigation moves by exactly three months.

Selection is always normalized before opening the modal:

- Clicking a date selects that date as both boundaries.
- Clicking an ISO week number selects Monday through Sunday.
- Clicking the month name selects the first through final day of that month.
- Pressing then dragging across dates selects both endpoints in chronological order, including every intervening date. Pointer events cover both mouse and touch input.

Opening and closing the modal uses a short opacity-and-scale transition. It displays editable start and end dates, title, a Trix rich-text editor, media attachment controls, and Save/Delete actions. A missing exact range means a new entry; an existing exact range means edit. Changing a range and saving resolves again under the uniqueness validation. The server returns validation feedback into the modal without discarding its contents.

Diary entries are marked on the calendar when their range intersects displayed days; the indicator is informational and does not change selection behaviour.

## Draft Cache

The modal saves an unsaved draft to `localStorage` after edits, keyed by the authenticated local user ID and selected range. A cache record contains the title, editor HTML, start date, end date, and an expiry timestamp 24 hours later. Expired records are discarded on read. Successful save and delete remove matching cached drafts. Files themselves are not cached locally; uploaded attachments remain managed by Active Storage.

## Error Handling and Security

- Every lookup is scoped to `current_local_user`.
- Invalid date input, reversed dates, missing title, and a duplicate exact range produce actionable validation errors.
- The modal retains its unsaved content if a request fails.
- Action Text sanitizes editor markup, and Active Storage controls attachment lifecycle.

## Testing

Add model, controller, integration, and system coverage for:

- Date-range normalization for day, ISO week, month, and pointer selection.
- Validations, exact-range uniqueness, and acceptance of partial overlaps.
- User isolation and inaccessible foreign entries.
- Notes-list range labels and Diary quarter navigation.
- Create, exact-range edit, date-range changes, delete, modal transition, draft expiry/restore, and rich-text attachment flow.

## Non-goals

- Replacing or migrating ordinary Notes.
- Calendar sharing, reminders, recurrence, or collaboration.
- Offline caching of binary media files.
