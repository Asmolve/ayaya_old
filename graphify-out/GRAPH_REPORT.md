# Graph Report - ayaya  (2026-08-02)

## Corpus Check
- 140 files · ~47,727 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 573 nodes · 560 edges · 118 communities (74 shown, 44 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ccaed929`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Ayaya Module Contract v1
- TestCase
- Client
- Ayaya Architecture Constitution
- RegisteredModule
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
- Note
- CreateNotes
- NoteTest
- StatusController
- Internal::Ayaya::StatusControllerTest
- create_app
- client.rb
- TestCase

## God Nodes (most connected - your core abstractions)
1. `Ayaya Architecture Constitution` - 24 edges
2. `Ayaya Module Contract v1` - 21 edges
3. `Reference Notes Module Design` - 19 edges
4. `Admin UI/UX Improvements Design` - 19 edges
5. `create_app()` - 18 edges
6. `RegisteredModule` - 17 edges
7. `File Structure` - 13 edges
8. `NotesController` - 12 edges
9. `17. Вопросы для уточнения` - 11 edges
10. `write_manifest()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `create_app()` --indirect_call--> `require_adapter_secret()`  [INFERRED]
  modules/notes/adapter/app/main.py → modules/notes/adapter/app/auth.py
- `test_live_requires_adapter_secret()` --calls--> `create_app()`  [INFERRED]
  modules/notes/adapter/tests/test_health_status.py → modules/notes/adapter/app/main.py
- `test_live_returns_ok()` --calls--> `create_app()`  [INFERRED]
  modules/notes/adapter/tests/test_health_status.py → modules/notes/adapter/app/main.py
- `test_ready_fails_when_notes_app_reports_unhealthy()` --calls--> `create_app()`  [INFERRED]
  modules/notes/adapter/tests/test_health_status.py → modules/notes/adapter/app/main.py
- `test_ready_fails_when_notes_app_status_is_unreachable()` --calls--> `create_app()`  [INFERRED]
  modules/notes/adapter/tests/test_health_status.py → modules/notes/adapter/app/main.py

## Import Cycles
- None detected.

## Communities (118 total, 44 thin omitted)

### Community 0 - "Ayaya Module Contract v1"
Cohesion: 0.06
Nodes (15): HomeController, ApplicationController, Internal, ModuleAccessController, ApplicationController, ApplicationRecord, RegisteredModule, TestCase (+7 more)

### Community 1 - "TestCase"
Cohesion: 0.07
Nodes (26): 10. `GET /ayaya/status`, 11. NGINX Routing, 12. Trusted Identity Headers, 13. Local Users, 14. Module Authorization, 15. Database, 16. Deployment Metadata, 17. Background Jobs (+18 more)

### Community 2 - "Client"
Cohesion: 0.08
Nodes (24): 10. Module Registry, 11. Manifest Truth, 12. Manifest Snapshot And Refresh, 13. Module State Model, 14. Module Access Policy, 15. Database Ownership, 16. Deployment Discipline, 17. Background Jobs (+16 more)

### Community 3 - "Ayaya Architecture Constitution"
Cohesion: 0.06
Nodes (30): 10. Хранение данных, 11. Scheduler, 12. Интеграции, 13. Развёртывание, 14. Масштабирование, 15. Нефункциональные требования, 16. Предварительная архитектура, 17. Вопросы для уточнения (+22 more)

### Community 4 - "RegisteredModule"
Cohesion: 0.10
Nodes (12): failure_result(), reference_notes_runtime?(), refresh_reference_manifest(), refresh_reference_status(), Modules, RefreshStatus, Result, Modules (+4 more)

### Community 5 - "init_spec.md"
Cohesion: 0.11
Nodes (17): Ayaya Core Foundation Implementation Plan, File Structure, Global Constraints, Scope Check, Self-Review Checklist, Task 10: Add Contract Test Harness Skeleton, Task 11: Add Static NGINX Example And Operational Notes, Task 12: Final Verification For Core Foundation (+9 more)

### Community 6 - "File Structure"
Cohesion: 0.28
Nodes (3): AyayaContract, Result, Runner

### Community 9 - "17. Вопросы для уточнения"
Cohesion: 0.33
Nodes (3): AdapterProtocol, ManifestValidator, Result

### Community 10 - "AyayaContract::ComposeExposureTest"
Cohesion: 0.15
Nodes (10): AdapterProtocol, Client, Error, InvalidResponse, Unauthorized, Unavailable, Modules, RefreshManifest (+2 more)

### Community 11 - "Runner"
Cohesion: 0.18
Nodes (10): Ayaya Project Overview, Core Responsibilities, Core Technology Choices, Explicitly Out Of Scope For Version 1, First Reference Module, Module Responsibilities, Module Technology Choices, Product Shape (+2 more)

### Community 13 - "Ayaya Core Foundation Notes"
Cohesion: 0.11
Nodes (15): ActiveAdmin, Ayaya Core Foundation Notes, Docker Development Runtime, Foundation Verification, Module Registry, NGINX Static Routing, Bundle Runtime, Development (+7 more)

### Community 14 - "CreateActiveAdminComments"
Cohesion: 0.40
Nodes (3): SystemTestCase, ApplicationSystemTestCase, HomeTest

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
Cohesion: 0.12
Nodes (5): AyayaIdentity, NotesController, ApplicationController, LocalUser, ApplicationRecord

### Community 113 - "StatusController"
Cohesion: 0.29
Nodes (4): Ayaya, Internal, ApplicationController, StatusController

### Community 115 - "create_app"
Cohesion: 0.13
Nodes (31): BaseModel, FastAPI, MockTransport, require_adapter_secret(), create_app(), BaseTransport, load_manifest(), Any (+23 more)

### Community 116 - "client.rb"
Cohesion: 0.22
Nodes (8): Admin UI/UX Improvements Implementation Plan, File Structure, Final Verification, Global Constraints, Task 1: RegisteredModule State Helpers, Task 2: ActiveAdmin Dashboard Operations Overview, Task 3: Registered Modules Resource UX Cleanup, Task 4: Module Operational Admin Actions

## Knowledge Gaps
- **190 isolated node(s):** `Internal`, `ApplicationHelper`, `AdapterProtocol`, `AdapterProtocol`, `Result` (+185 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **44 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RegisteredModule` connect `Ayaya Module Contract v1` to `RegisteredModule`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `NotesController` connect `NotesController` to `RegisteredModule`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `Client` connect `AyayaContract::ComposeExposureTest` to `RegisteredModule`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Are the 13 inferred relationships involving `create_app()` (e.g. with `require_adapter_secret()` and `test_live_requires_adapter_secret()`) actually correct?**
  _`create_app()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Internal`, `ApplicationHelper`, `AdapterProtocol` to the rest of the system?**
  _190 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Ayaya Module Contract v1` be split into smaller, more focused modules?**
  _Cohesion score 0.06258890469416785 - nodes in this community are weakly interconnected._
- **Should `TestCase` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._