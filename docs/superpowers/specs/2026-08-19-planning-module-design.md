# Planning module design

## Goal

Add an independently deployable `planning` module to Ayaya that helps a user turn a vague plan into a visible, prioritized set of actionable items. The first release is deliberately local to one authenticated user: no collaboration, notifications, due-date automation, or Core changes.

## Product shape

The module opens on a single “Priority Map” workspace. The left rail lists the user’s plans; the main canvas groups items into `Now`, `Next`, and `Later` lanes; a compact inspector edits the selected item. Items can be created inline, edited in the inspector, moved between priority lanes, reordered within a lane, completed, and deleted. Empty states explain the next action instead of showing a dashboard mosaic.

Visual thesis: a calm editorial planning desk — warm paper surface, ink typography, one amber accent, and a clear horizontal priority horizon that makes the next decision obvious.

Content plan: orientation header and active plan; priority canvas as the primary work surface; inspector as focused detail; a concise empty state for first use.

Interaction thesis: lane transitions animate lightly, dragging gives a visible insertion cue, and selecting an item opens the inspector without losing canvas context. All interactions have keyboard/button fallbacks and respect reduced motion.

## Architecture

Create `modules/planning/` by following the existing `modules/notes/` bundle shape:

- Rails 8 Module App with its own PostgreSQL database;
- FastAPI Adapter exposing the v1 manifest, health, readiness, and status endpoints;
- `module.yml`, `compose.yml`, and module docs;
- no Core domain tables or planning business logic. A minimal Core registry integration is allowed and required: local adapter registration, adapter-secret lookup, admin registration action, and platform routing/network configuration.

The Rails app trusts the existing Ayaya identity headers through a module-local concern. `LocalUser` owns `plans` and `plan_items`. `PlanItem` stores title, notes, priority (`now`, `next`, `later`), position, and completion state. A plan belongs to one local user and items cannot be read or mutated outside that owner.

Routes are under `/m/planning`: root workspace, plan CRUD, item CRUD, and `PATCH /m/planning/plan_items/:id/position` for lane/order changes. The position endpoint accepts `{priority, position}` and returns the updated item as JSON. Positions are normalized transactionally per plan and priority so repeated moves do not create unbounded gaps.

## Error handling and security

All HTML controllers require Ayaya identity and scope lookups through `current_local_user`. Missing records return 404. Invalid item titles or priority values render a 422 form response or JSON error. The position endpoint uses normal Rails CSRF protection and rejects invalid payloads with 422. The internal status endpoint requires the module-specific bearer secret and returns database health without leaking credentials.

## Verification

Use model, controller, system, and adapter tests. Required user-facing coverage includes: first-use empty state; creating a plan and item; moving an item between priority lanes; reordering within a lane; completing an item; rejecting cross-user access; responsive inspector behavior; keyboard-accessible move controls; and adapter secret/manifest/status contract behavior. Run the module test suite, adapter pytest suite, RuboCop/Brakeman where available, and `graphify update .` after code changes.

## Explicit non-goals

No multi-user sharing, comments, attachments, recurrence, calendar integration, external APIs, drag-and-drop-only workflows, or Core module registration changes are part of this release.
