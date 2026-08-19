# Graph Report - ayaya  (2026-08-19)

## Corpus Check
- 222 files · ~73,539 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1052 nodes · 1093 edges · 208 communities (110 shown, 98 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 34 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c5ea9243`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Ayaya Module Contract v1
- TestCase
- Client
- Ayaya Architecture Constitution
- Техническое задание: Telegram Dialog Organizer — модуль Ayaya
- init_spec.md
- File Structure
- User
- ManifestValidator
- 17. Вопросы для уточнения
- AyayaContract::ComposeExposureTest
- Runner
- RefreshStatus
- Ayaya Core Foundation Notes
- CreateActiveAdminComments
- manifest_loader.rb
- ApplicationJob
- ApplicationController
- Application
- DeviseCreateUsers
- AddPlatformFieldsToUsers
- CreateRegisteredModules
- CreateModuleUserAccesses
- ApplicationSystemTestCase
- HomeControllerTest
- Internal::ModuleAccessControllerTest
- AdminAccessTest
- AGENTS.md
- application_helper.rb
- docker-entrypoint
- setup
- registered_modules.rb
- HomeTest
- 2026-08-01-reference-notes-module.md
- ApplicationRecord
- CONTRACT.md
- FakeClient
- test_helper.rb
- ApplicationRecord
- ModuleUserAccess
- Ayaya Core Foundation Notes
- ApplicationJob
- ApplicationMailer
- Admin UI/UX Improvements Design
- Application
- test_helper.rb
- AyayaContract::RunnerTest
- UserTest
- AdapterProtocol::ClientTest
- AdapterProtocol::ManifestValidatorTest
- application_helper.rb
- docker-entrypoint
- README.md
- NotesController
- CreateLocalUsers
- AyayaIdentityTest
- LocalUserTest
- .for
- CreateNotes
- AyayaIdentity
- StatusController
- Internal::Ayaya::StatusControllerTest
- create_app
- client.rb
- TestCase
- Diary Mode Design
- CreateActiveStorageTables
- TestCase
- CreateActionTextTables
- AddDiaryFieldsToNotes
- new_framework_defaults_8_1.rb
- ApplicationRecord
- TestCase
- DiaryControllerTest
- DiaryController
- ApplicationController
- AyayaContract::PicObtainerModuleTest
- Pic Obtainer Ayaya Integration Design
- Repository map
- README.md
- Runner
- REGISTER.md
- Admin-Driven Local Module Registration Implementation Plan
- PicObtainerModuleSystemTest
- Modules::LocalRegistrationTest
- ModuleAccessController
- Modules::RefreshManifestTest
- Modules::RefreshStatusTest
- PicObtainerModuleTest
- HomeController
- create_app
- Planning module implementation plan
- Planning module design
- Planning Module
- Application
- docker-entrypoint
- README.md
- test_helper.rb
- CONTRACT.md
- REGISTER.md
- Settings
- load_manifest
- Any
- BaseTransport
- FastAPI
- Settings
- PlanItemsController
- AyayaIdentityTest
- PlanItemsControllerTest
- PlansControllerTest
- CreateLocalUsers
- CreatePlans
- CreatePlanItems
- LocalUserTest
- PlanItemTest
- PlanTest
- PlanItemsController
- PlansController
- PriorityMap
- PriorityMapTest
- Runner
- AdminAccessTest
- LocalRegistration
- client.rb
- StatusController
- RefreshStatus
- registered_modules.rb
- ApplicationSystemTestCase
- Client
- load_manifest
- RegisteredModuleTest
- PlanningStatusControllerTest
- refresh_manifest.rb
- ApplicationSystemTestCase
- ApplicationSystemTestCase
- Any
- BaseTransport
- FastAPI
- MockTransport
- Path
- ApplicationController
- IntegrationTest

## God Nodes (most connected - your core abstractions)
1. `DiaryCalendar` - 29 edges
2. `Ayaya Architecture Constitution` - 24 edges
3. `RegisteredModule` - 21 edges
4. `Ayaya Module Contract v1` - 21 edges
5. `Техническое задание: Telegram Dialog Organizer — модуль Ayaya` - 20 edges
6. `Reference Notes Module Design` - 19 edges
7. `Admin UI/UX Improvements Design` - 19 edges
8. `create_app()` - 18 edges
9. `create_app()` - 17 edges
10. `PlanItemsController` - 16 edges

## Surprising Connections (you probably didn't know these)
- `test_manifest_returns_shipped_module_yml()` --calls--> `create_app()`  [INFERRED]
  modules/planning/adapter/tests/test_manifest.py → modules/planning/adapter/app/main.py
- `test_health_endpoints_reject_a_planning_status_with_missing_or_wrong_module_key()` --calls--> `create_app()`  [INFERRED]
  modules/planning/adapter/tests/test_health_status.py → modules/planning/adapter/app/main.py
- `test_live_requires_adapter_secret()` --calls--> `create_app()`  [INFERRED]
  modules/planning/adapter/tests/test_health_status.py → modules/planning/adapter/app/main.py
- `test_live_returns_ok()` --calls--> `create_app()`  [INFERRED]
  modules/planning/adapter/tests/test_health_status.py → modules/planning/adapter/app/main.py
- `test_ready_and_status_reject_missing_adapter_secret()` --calls--> `create_app()`  [INFERRED]
  modules/planning/adapter/tests/test_health_status.py → modules/planning/adapter/app/main.py

## Import Cycles
- None detected.

## Communities (208 total, 98 thin omitted)

### Community 1 - "TestCase"
Cohesion: 0.07
Nodes (26): 10. `GET /ayaya/status`, 11. NGINX Routing, 12. Trusted Identity Headers, 13. Local Users, 14. Module Authorization, 15. Database, 16. Deployment Metadata, 17. Background Jobs (+18 more)

### Community 2 - "Client"
Cohesion: 0.08
Nodes (24): 10. Module Registry, 11. Manifest Truth, 12. Manifest Snapshot And Refresh, 13. Module State Model, 14. Module Access Policy, 15. Database Ownership, 16. Deployment Discipline, 17. Background Jobs (+16 more)

### Community 3 - "Ayaya Architecture Constitution"
Cohesion: 0.06
Nodes (30): 10. Хранение данных, 11. Scheduler, 12. Интеграции, 13. Развёртывание, 14. Масштабирование, 15. Нефункциональные требования, 16. Предварительная архитектура, 17. Вопросы для уточнения (+22 more)

### Community 4 - "Техническое задание: Telegram Dialog Organizer — модуль Ayaya"
Cohesion: 0.07
Nodes (26): 10.1. Анализ, 10.2. Применение, 10.3. Повторный запуск и откат, 10. Flow синхронизации, 11. Внутренний статус приложения, 12. Хранение данных, 13. Ошибки и ограничения, 14. Приватность и журналирование (+18 more)

### Community 5 - "init_spec.md"
Cohesion: 0.11
Nodes (17): Ayaya Core Foundation Implementation Plan, File Structure, Global Constraints, Scope Check, Self-Review Checklist, Task 10: Add Contract Test Harness Skeleton, Task 11: Add Static NGINX Example And Operational Notes, Task 12: Final Verification For Core Foundation (+9 more)

### Community 6 - "File Structure"
Cohesion: 0.17
Nodes (11): ActiveAdmin workflow, Admin-Driven Local Module Registration Design, Authorization, Design, Error handling, Future unification, Goal, Registration configuration boundary (+3 more)

### Community 9 - "17. Вопросы для уточнения"
Cohesion: 0.33
Nodes (3): AdapterProtocol, ManifestValidator, Result

### Community 10 - "AyayaContract::ComposeExposureTest"
Cohesion: 0.15
Nodes (4): DiaryCalendar, draftKey(), expiresAt(), normalizeRange()

### Community 11 - "Runner"
Cohesion: 0.18
Nodes (10): Ayaya Project Overview, Core Responsibilities, Core Technology Choices, Explicitly Out Of Scope For Version 1, First Reference Module, Module Responsibilities, Module Technology Choices, Product Shape (+2 more)

### Community 13 - "Ayaya Core Foundation Notes"
Cohesion: 0.11
Nodes (15): ActiveAdmin, Ayaya Core Foundation Notes, Docker Development Runtime, Foundation Verification, Module Registry, NGINX Static Routing, Bundle Runtime, Development (+7 more)

### Community 61 - "HomeTest"
Cohesion: 0.10
Nodes (19): Acceptance Criteria, Adapter Protocol, Architecture, Compose Integration, Database, Internal Status Endpoint, Local Users, Manifest (+11 more)

### Community 62 - "2026-08-01-reference-notes-module.md"
Cohesion: 0.22
Nodes (8): File Structure, Global Constraints, Notes Contract, Reference Notes Module Implementation Plan, Register Notes In Core, Smoke Test, syntax=docker/dockerfile:1, Task 1: Module Bundle Skeleton And Manifest

### Community 65 - "FakeClient"
Cohesion: 0.33
Nodes (3): FakeClient, Modules::RegisterAdapterTest, TestCase

### Community 66 - "test_helper.rb"
Cohesion: 0.50
Nodes (3): ActionDispatch::IntegrationTest, ActiveSupport, TestCase

### Community 72 - "Admin UI/UX Improvements Design"
Cohesion: 0.08
Nodes (25): Acceptance Criteria, Admin Actions, Admin UI/UX Improvements Design, Current Problems, Dashboard Requirements, Data Flow, Disable Module, Enable Module (+17 more)

### Community 104 - "NotesController"
Cohesion: 0.17
Nodes (5): DiaryController, ApplicationController, DiaryHelper, DiaryHelperTest, TestCase

### Community 110 - ".for"
Cohesion: 0.27
Nodes (3): Modules, RegisterAdapter, Result

### Community 112 - "AyayaIdentity"
Cohesion: 0.29
Nodes (6): Asset Delivery, Diary Visual Refresh Design, Goal, Modal Editor, Navigation and Calendar, Verification

### Community 113 - "StatusController"
Cohesion: 0.29
Nodes (4): Ayaya, Internal, ApplicationController, StatusController

### Community 115 - "create_app"
Cohesion: 0.11
Nodes (33): Settings, require_adapter_secret(), create_app(), BaseTransport, FastAPI, load_manifest(), Any, get_settings() (+25 more)

### Community 116 - "client.rb"
Cohesion: 0.22
Nodes (8): Admin UI/UX Improvements Implementation Plan, File Structure, Final Verification, Global Constraints, Task 1: RegisteredModule State Helpers, Task 2: ActiveAdmin Dashboard Operations Overview, Task 3: Registered Modules Resource UX Cleanup, Task 4: Module Operational Admin Actions

### Community 117 - "TestCase"
Cohesion: 0.22
Nodes (8): Diary Mode Implementation Plan, File Structure, Global Constraints, Task 1: Add Diary persistence and rich-content infrastructure, Task 2: Add scoped Diary routes and date-range helpers, Task 3: Render three-month Diary UI and Action Text editor, Task 4: Add selection, modal behaviour, and 24-hour drafts, Task 5: Verify end-to-end integration and refresh the graph

### Community 118 - "Diary Mode Design"
Cohesion: 0.18
Nodes (10): Calendar and Modal UX, Data Model, Diary Mode Design, Draft Cache, Error Handling and Security, Goal, Non-goals, Routes and Server Behaviour (+2 more)

### Community 123 - "new_framework_defaults_8_1.rb"
Cohesion: 0.40
Nodes (4): Diary Visual Refresh Implementation Plan, Global Constraints, Task 1: Route Notes assets through the module, Task 2: Polish Diary navigation, calendar, and modal editor

### Community 124 - "ApplicationRecord"
Cohesion: 0.14
Nodes (3): ApplicationSystemTestCase, DiaryCalendarTest, HomeTest

### Community 132 - "Pic Obtainer Ayaya Integration Design"
Cohesion: 0.12
Nodes (15): Acceptance criteria, Architecture, Ayaya identity and access, Ayaya module contract, Configuration and secrets, Data and storage, Error handling, Goal (+7 more)

### Community 133 - "Repository map"
Cohesion: 0.13
Nodes (14): Global Constraints, Pic Obtainer Ayaya Integration Implementation Plan, Repository map, Task 1: Define the independent module deployment boundary, Task 2: Add the authenticated Ayaya adapter surface, Task 3: Add trusted Ayaya identity handling, Task 4: Add the server-rendered GUI over the existing facade, Task 5: Make media/import paths safe for the module deployment (+6 more)

### Community 135 - "Runner"
Cohesion: 0.17
Nodes (7): failure_result(), refresh_reference_manifest(), refresh_reference_status(), AdapterSecret, Modules, Modules, RegisterReferenceNotes

### Community 137 - "Admin-Driven Local Module Registration Implementation Plan"
Cohesion: 0.25
Nodes (7): Admin-Driven Local Module Registration Implementation Plan, File Map, Global Constraints, Task 1: Add the local registration boundary, Task 2: Add the ActiveAdmin Pic Obtainer action, Task 3: Wire the configurable adapter URL into Compose and documentation, Task 4: Full verification and reviewer handoff

### Community 139 - "Modules::LocalRegistrationTest"
Cohesion: 0.22
Nodes (4): FailingClient, FakeClient, Modules::LocalRegistrationTest, TestCase

### Community 140 - "ModuleAccessController"
Cohesion: 0.33
Nodes (3): Internal, ModuleAccessController, ApplicationController

### Community 141 - "Modules::RefreshManifestTest"
Cohesion: 0.33
Nodes (3): FakeClient, Modules::RefreshManifestTest, TestCase

### Community 142 - "Modules::RefreshStatusTest"
Cohesion: 0.33
Nodes (3): FakeClient, Modules::RefreshStatusTest, TestCase

### Community 145 - "create_app"
Cohesion: 0.17
Nodes (26): Any, BaseTransport, FastAPI, MockTransport, create_app(), status_fields(), configure(), status_transport() (+18 more)

### Community 146 - "Planning module implementation plan"
Cohesion: 0.25
Nodes (7): Global constraints, Planning module implementation plan, Task 1: Scaffold planning bundle and adapter contract, Task 2: Domain model, identity, migrations, and HTML CRUD, Task 3: Priority Map UI and interaction behavior, Task 4: Position endpoint and health integration, Task 5: Whole-branch verification and cleanup

### Community 147 - "Planning module design"
Cohesion: 0.25
Nodes (7): Architecture, Error handling and security, Explicit non-goals, Goal, Planning module design, Product shape, Verification

### Community 148 - "Planning Module"
Cohesion: 0.20
Nodes (9): Core registration and enablement, Deployment operations, Development, Health and position routes, NGINX and trusted identity, Persistent data, backups, and retention, Planning Module, Rollback (+1 more)

### Community 186 - "Runner"
Cohesion: 0.28
Nodes (3): AyayaContract, Result, Runner

### Community 187 - "AdminAccessTest"
Cohesion: 0.09
Nodes (13): AdapterProtocol, Client, Error, InvalidResponse, StandardError, Unauthorized, Unavailable, Modules (+5 more)

### Community 188 - "LocalRegistration"
Cohesion: 0.29
Nodes (3): Configuration, LocalRegistration, Modules

### Community 189 - "client.rb"
Cohesion: 0.15
Nodes (7): ApplicationController, Base, PlanItem, ApplicationRecord, InvalidPayload, PlanItemPositioner, StandardError

### Community 190 - "StatusController"
Cohesion: 0.29
Nodes (4): Ayaya, Internal, ApplicationController, StatusController

### Community 191 - "RefreshStatus"
Cohesion: 0.33
Nodes (3): Modules, RefreshStatus, Result

### Community 192 - "registered_modules.rb"
Cohesion: 0.23
Nodes (9): Settings, require_adapter_secret(), get_settings(), BaseModel, Settings, fetch_planning_app_status(), Any, BaseTransport (+1 more)

## Knowledge Gaps
- **308 isolated node(s):** `Internal`, `ApplicationHelper`, `AdapterProtocol`, `AdapterProtocol`, `Result` (+303 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **98 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RegisteredModule` connect `Ayaya Module Contract v1` to `RegisteredModuleTest`, `Runner`, `Modules::LocalRegistrationTest`, `ModuleAccessController`, `Modules::RefreshManifestTest`, `.for`, `PicObtainerModuleTest`, `HomeController`, `Modules::RefreshStatusTest`, `AdminAccessTest`, `LocalRegistration`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `NotesController` connect `AGENTS.md` to `.for`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `Client` connect `AdminAccessTest` to `.for`, `RefreshStatus`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `Internal`, `ApplicationHelper`, `AdapterProtocol` to the rest of the system?**
  _308 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `TestCase` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `Client` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Ayaya Architecture Constitution` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._