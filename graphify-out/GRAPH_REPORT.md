# Graph Report - ayaya  (2026-08-26)

## Corpus Check
- 371 files · ~101,979 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1888 nodes · 2312 edges · 338 communities (152 shown, 186 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 81 edges (avg confidence: 0.78)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1fcb201d`
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
- AyayaIdentity
- ApplicationSystemTestCase
- CanonicalSnapshot
- rule_classifier.rb
- AccountLease
- Folder
- test_helper.rb
- local_registration_test.rb
- AccountsController
- ApplicationController
- DashboardController
- ImportsController
- OperationsController
- ApplicationRecord
- Assignment
- Dialog
- Operation
- OperationStep
- OperationStep
- Snapshot
- TelegramAccount
- Application
- CreateTelegramDomain
- IdentityAndSecurityTest
- TelegramStatusControllerTest
- CrossUserIsolationTest
- CanonicalSnapshotTest
- DynamicLimitsTest
- EncryptedSecretTest
- ReconciliationTest
- RuleClassifierTest
- Modules::AdapterSecretTest
- __init__.py
- DynamicLimits
- ReadOnlyImport
- Reconciler
- StaticKeyProvider
- registered_modules.rb
- AccountLease
- confirmation_required.rb
- key_unavailable.rb
- operation_executor.rb
- CsrfProtectionTest
- OwnershipTest
- ClientRegistryTest
- DisconnectAccountTest
- PrivacyLoggingTest
- ReadOnlyImportTest
- telegram.rb
- test_client.rb
- client.rb
- AssignmentsController
- RulesController
- Ownership
- client_not_configured.rb
- client_response_error.rb
- outcome_unknown.rb
- preflight_conflict.rb
- read_only_violation.rb
- HardenTelegramOperations
- RecordingHttp
- FolderProposal
- TaskTenOrganizerProposalsTest
- registered_modules.rb
- TaskTenWorkerTest
- AddDurableWorkerSchedule
- AddFolderProposalsAndOwnershipState
- AddDurableOrganizerStateTest
- TaskTenFilterFidelityTest
- FloodWait
- DashboardController
- refresh_manifest.rb
- dispatch_not_started.rb
- manifest_validator.rb
- AddAvatarUrlToDialogs
- AddRateLimitPauseToTelegramAccounts
- TaskTenDashboardReviewTest
- TaskTenRollbackTest
- AddFolderProposalsAndOwnershipStateTest
- RuleTest
- RetentionPurgeTest
- ApplicationController
- Settings
- FastAPI
- BaseModel
- Settings
- MockTransport
- ApplicationController
- ApplicationController
- ApplicationController
- ApplicationController
- ApplicationController
- ApplicationController
- ApplicationController
- ApplicationJob
- ApplicationJob
- ApplicationJob
- ApplicationRecord
- ApplicationRecord
- ApplicationRecord
- ApplicationRecord
- ApplicationRecord
- ApplicationRecord
- ApplicationRecord
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- TestCase
- Global Constraints
- Telegram MTProto Transport Design
- .decrypt
- client_registry.rb
- FloodWait
- DisconnectAccount

## God Nodes (most connected - your core abstractions)
1. `TestCase` - 29 edges
2. `DiaryCalendar` - 29 edges
3. `TestClient` - 25 edges
4. `create_app()` - 24 edges
5. `Ayaya Architecture Constitution` - 24 edges
6. `Ayaya Module Contract v1` - 21 edges
7. `TelethonGateway` - 20 edges
8. `Техническое задание: Telegram Dialog Organizer — модуль Ayaya` - 20 edges
9. `create_app()` - 20 edges
10. `Reference Notes Module Design` - 19 edges

## Surprising Connections (you probably didn't know these)
- `AddFolderProposalsAndOwnershipStateTest` --inherits--> `TestCase`  [EXTRACTED]
  modules/telegram/app/test/migrations/add_folder_proposals_and_ownership_state_test.rb → test/test_helper.rb
- `RuleTest` --inherits--> `TestCase`  [EXTRACTED]
  modules/telegram/app/test/models/rule_test.rb → test/test_helper.rb
- `CanonicalSnapshotTest` --inherits--> `TestCase`  [EXTRACTED]
  modules/telegram/app/test/services/canonical_snapshot_test.rb → test/test_helper.rb
- `ClientRegistryTest` --inherits--> `TestCase`  [EXTRACTED]
  modules/telegram/app/test/services/client_registry_test.rb → test/test_helper.rb
- `DisconnectAccountTest` --inherits--> `TestCase`  [EXTRACTED]
  modules/telegram/app/test/services/disconnect_account_test.rb → test/test_helper.rb

## Import Cycles
- None detected.

## Communities (338 total, 186 thin omitted)

### Community 0 - "Ayaya Module Contract v1"
Cohesion: 0.06
Nodes (16): HomeController, ApplicationController, ApplicationRecord, RegisteredModule, Modules, RegisterReferenceNotes, PicObtainerModuleTest, IntegrationTest (+8 more)

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
Cohesion: 0.28
Nodes (3): AyayaContract, Result, Runner

### Community 10 - "AyayaContract::ComposeExposureTest"
Cohesion: 0.15
Nodes (4): DiaryCalendar, draftKey(), expiresAt(), normalizeRange()

### Community 11 - "Runner"
Cohesion: 0.18
Nodes (10): Ayaya Project Overview, Core Responsibilities, Core Technology Choices, Explicitly Out Of Scope For Version 1, First Reference Module, Module Responsibilities, Module Technology Choices, Product Shape (+2 more)

### Community 12 - "RefreshStatus"
Cohesion: 0.22
Nodes (4): Note, ApplicationRecord, NotesControllerTest, IntegrationTest

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

### Community 72 - "Admin UI/UX Improvements Design"
Cohesion: 0.08
Nodes (25): Acceptance Criteria, Admin Actions, Admin UI/UX Improvements Design, Current Problems, Dashboard Requirements, Data Flow, Disable Module, Enable Module (+17 more)

### Community 77 - "AdapterProtocol::ClientTest"
Cohesion: 0.12
Nodes (9): DockerImageTest, AddDurableOrganizerStateTest, OwnershipTest, EncryptedSecretTest, PrivacyLoggingTest, ReadOnlyImportTest, ReconciliationTest, AdapterProtocol::ClientTest (+1 more)

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

### Community 128 - "ApplicationController"
Cohesion: 0.14
Nodes (32): MockTransport, create_app(), BaseTransport, configure(), healthy_status(), Path, request(), status_transport() (+24 more)

### Community 132 - "Pic Obtainer Ayaya Integration Design"
Cohesion: 0.12
Nodes (15): Acceptance criteria, Architecture, Ayaya identity and access, Ayaya module contract, Configuration and secrets, Data and storage, Error handling, Goal (+7 more)

### Community 133 - "Repository map"
Cohesion: 0.13
Nodes (14): Global Constraints, Pic Obtainer Ayaya Integration Implementation Plan, Repository map, Task 1: Define the independent module deployment boundary, Task 2: Add the authenticated Ayaya adapter surface, Task 3: Add trusted Ayaya identity handling, Task 4: Add the server-rendered GUI over the existing facade, Task 5: Make media/import paths safe for the module deployment (+6 more)

### Community 135 - "Runner"
Cohesion: 0.33
Nodes (3): Modules, RefreshStatus, Result

### Community 137 - "Admin-Driven Local Module Registration Implementation Plan"
Cohesion: 0.25
Nodes (7): Admin-Driven Local Module Registration Implementation Plan, File Map, Global Constraints, Task 1: Add the local registration boundary, Task 2: Add the ActiveAdmin Pic Obtainer action, Task 3: Wire the configurable adapter URL into Compose and documentation, Task 4: Full verification and reviewer handoff

### Community 139 - "Modules::LocalRegistrationTest"
Cohesion: 0.24
Nodes (3): FailingClient, FakeClient, Modules::LocalRegistrationTest

### Community 141 - "Modules::RefreshManifestTest"
Cohesion: 0.15
Nodes (7): Telegram, TrustedIdentity, AssignmentReviewTest, IntegrationTest, ActionDispatch::IntegrationTest, ActiveSupport::TestCase, AyayaTestIdentity

### Community 142 - "Modules::RefreshStatusTest"
Cohesion: 0.07
Nodes (19): FastAPI, require_client_token(), Challenge, ChallengeRegistry, new_handle(), create_app(), main(), router() (+11 more)

### Community 145 - "create_app"
Cohesion: 0.11
Nodes (35): Settings, require_adapter_secret(), create_app(), BaseTransport, FastAPI, load_manifest(), Any, get_settings() (+27 more)

### Community 146 - "Planning module implementation plan"
Cohesion: 0.25
Nodes (7): Global constraints, Planning module implementation plan, Task 1: Scaffold planning bundle and adapter contract, Task 2: Domain model, identity, migrations, and HTML CRUD, Task 3: Priority Map UI and interaction behavior, Task 4: Position endpoint and health integration, Task 5: Whole-branch verification and cleanup

### Community 147 - "Planning module design"
Cohesion: 0.25
Nodes (7): Architecture, Error handling and security, Explicit non-goals, Goal, Planning module design, Product shape, Verification

### Community 148 - "Planning Module"
Cohesion: 0.20
Nodes (9): Core registration and enablement, Deployment operations, Development, Health and position routes, NGINX and trusted identity, Persistent data, backups, and retention, Planning Module, Rollback (+1 more)

### Community 181 - "PlanItemsController"
Cohesion: 0.08
Nodes (11): ApplicationController, Base, PlanItemsController, ApplicationController, PlanItem, ApplicationRecord, Plan, ApplicationRecord (+3 more)

### Community 187 - "AdminAccessTest"
Cohesion: 0.17
Nodes (5): Client, Telegram, AdminAccessTest, PicObtainerRegistrationClient, IntegrationTest

### Community 188 - "LocalRegistration"
Cohesion: 0.22
Nodes (4): JsonBoundary, Telegram, ReadOnlyImport, Telegram

### Community 189 - "client.rb"
Cohesion: 0.13
Nodes (25): BaseModel, Any, status_fields(), require_adapter_secret(), component_runtime_status(), Any, rfc3339_now(), sanitized_degraded_reasons() (+17 more)

### Community 190 - "StatusController"
Cohesion: 0.29
Nodes (4): Ayaya, Internal, ApplicationController, StatusController

### Community 192 - "registered_modules.rb"
Cohesion: 0.09
Nodes (9): Ayaya, Internal, StatusController, EnvironmentKeyProvider, Telegram, KeyProvider, Telegram, SecretFileKeyProvider (+1 more)

### Community 194 - "Client"
Cohesion: 0.20
Nodes (8): Telegram Dialog Organizer Contract, Build, migrate, start, and health, Manual live Telegram smoke test, NGINX and Core integration, Required environment, Rollback and recovery, Services and topology, Telegram Dialog Organizer

### Community 198 - "AyayaIdentity"
Cohesion: 0.13
Nodes (4): ModuleUser, TelegramAccount, OperationExecutorTest, ReviewRemediationTest

### Community 201 - "rule_classifier.rb"
Cohesion: 0.06
Nodes (16): failure_result(), refresh_reference_manifest(), refresh_reference_status(), AdapterSecret, Modules, Configuration, LocalRegistration, Modules (+8 more)

### Community 202 - "AccountLease"
Cohesion: 0.14
Nodes (4): DesiredStateBuilder, Telegram, FilterState, Telegram

### Community 203 - "Folder"
Cohesion: 0.12
Nodes (6): ApplicationRecord, Base, Assignment, Folder, FolderProposal, Snapshot

### Community 204 - "test_helper.rb"
Cohesion: 0.17
Nodes (4): PagedImportClient, HTTPOK, RecordingHttp, Response

### Community 205 - "local_registration_test.rb"
Cohesion: 0.22
Nodes (4): Reconciler, Telegram, StateComparison, Telegram

### Community 206 - "AccountsController"
Cohesion: 0.16
Nodes (3): Telegram, WorkerService, AddFolderProposalsAndOwnershipState

### Community 207 - "ApplicationController"
Cohesion: 0.20
Nodes (4): ApplicationController, Base, FolderProposalsController, ImportsController

### Community 209 - "ImportsController"
Cohesion: 0.14
Nodes (3): OperationWorker, Telegram, Operation

### Community 215 - "Operation"
Cohesion: 0.12
Nodes (4): ClientResult, TelethonGateway, client(), FakeStorage

### Community 218 - "Snapshot"
Cohesion: 0.15
Nodes (5): OperationStep, EncryptedPayload, Telegram, Redactor, Telegram

### Community 241 - "ReadOnlyImport"
Cohesion: 0.18
Nodes (6): ApplicationJob, Base, OperationRecoveryJob, Telegram, RetentionPurgeJob, Telegram

### Community 242 - "Reconciler"
Cohesion: 0.21
Nodes (3): AccountLease, OperationRecovery, Telegram

### Community 246 - "confirmation_required.rb"
Cohesion: 0.50
Nodes (3): ConfirmationRequired, StandardError, Telegram

### Community 247 - "key_unavailable.rb"
Cohesion: 0.50
Nodes (3): KeyUnavailable, StandardError, Telegram

### Community 248 - "operation_executor.rb"
Cohesion: 0.50
Nodes (3): LeaseUnavailable, StandardError, Telegram

### Community 259 - "client.rb"
Cohesion: 0.24
Nodes (7): AdapterProtocol, Client, Error, InvalidResponse, StandardError, Unauthorized, Unavailable

### Community 263 - "client_not_configured.rb"
Cohesion: 0.50
Nodes (3): ClientNotConfigured, StandardError, Telegram

### Community 264 - "client_response_error.rb"
Cohesion: 0.50
Nodes (3): ClientResponseError, StandardError, Telegram

### Community 265 - "outcome_unknown.rb"
Cohesion: 0.50
Nodes (3): OutcomeUnknown, StandardError, Telegram

### Community 266 - "preflight_conflict.rb"
Cohesion: 0.50
Nodes (3): PreflightConflict, StandardError, Telegram

### Community 267 - "read_only_violation.rb"
Cohesion: 0.50
Nodes (3): StandardError, ReadOnlyViolation, Telegram

### Community 269 - "RecordingHttp"
Cohesion: 0.20
Nodes (4): OpaqueHandleTransportTest, HTTPOK, RecordingHttp, Response

### Community 282 - "refresh_manifest.rb"
Cohesion: 0.40
Nodes (3): Modules, RefreshManifest, Result

### Community 283 - "dispatch_not_started.rb"
Cohesion: 0.50
Nodes (3): Error, DispatchNotStarted, Telegram

### Community 332 - "Global Constraints"
Cohesion: 0.22
Nodes (8): Global Constraints, Task 1: Create the transport package and dependency contract, Task 2: Add encrypted PostgreSQL session storage, Task 3: Implement login challenge lifecycle and session handles, Task 4: Implement state, import, and folder operations, Task 5: Wire PostgreSQL provisioning and Compose networking, Task 6: Full verification and handoff, Telegram MTProto Transport Implementation Plan

### Community 333 - "Telegram MTProto Transport Design"
Cohesion: 0.25
Nodes (7): Architecture, Goal, HTTP contract, PostgreSQL, Security and failure behavior, Telegram MTProto Transport Design, Verification

### Community 336 - "FloodWait"
Cohesion: 0.29
Nodes (3): FloodWait, StandardError, Telegram

## Knowledge Gaps
- **377 isolated node(s):** `Task 1: Create the transport package and dependency contract`, `Task 2: Add encrypted PostgreSQL session storage`, `Task 3: Implement login challenge lifecycle and session handles`, `Task 4: Implement state, import, and folder operations`, `Task 5: Wire PostgreSQL provisioning and Compose networking` (+372 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **186 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TestClient` connect `ApplicationController` to `FloodWait`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Why does `create_app()` connect `ApplicationController` to `client.rb`, `Modules::RefreshStatusTest`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **Are the 19 inferred relationships involving `create_app()` (e.g. with `require_adapter_secret()` and `test_adapter_does_not_expose_framework_documentation_endpoints()`) actually correct?**
  _`create_app()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Task 1: Create the transport package and dependency contract`, `Task 2: Add encrypted PostgreSQL session storage`, `Task 3: Implement login challenge lifecycle and session handles` to the rest of the system?**
  _377 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Ayaya Module Contract v1` be split into smaller, more focused modules?**
  _Cohesion score 0.05609756097560976 - nodes in this community are weakly interconnected._
- **Should `TestCase` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `Client` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._