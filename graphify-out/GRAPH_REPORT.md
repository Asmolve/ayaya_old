# Graph Report - ayaya  (2026-07-27)

## Corpus Check
- 76 files · ~25,455 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 310 nodes · 280 edges · 61 communities (44 shown, 17 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9e274c11`
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
- Ayaya Project Overview
- Runner
- RefreshStatus
- Ayaya Core Foundation Notes
- CreateActiveAdminComments
- manifest_loader.rb
- ApplicationJob
- ApplicationMailer
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
- README.md

## God Nodes (most connected - your core abstractions)
1. `Ayaya Architecture Constitution` - 24 edges
2. `Ayaya Module Contract v1` - 21 edges
3. `File Structure` - 13 edges
4. `17. Вопросы для уточнения` - 11 edges
5. `RegisteredModule` - 10 edges
6. `Ayaya Project Overview` - 10 edges
7. `ManifestValidator` - 9 edges
8. `TestCase` - 9 edges
9. `Client` - 8 edges
10. `User` - 7 edges

## Surprising Connections (you probably didn't know these)
- `ModuleUserAccess` --inherits--> `ApplicationRecord`  [EXTRACTED]
  app/models/module_user_access.rb → app/models/application_record.rb
- `RegisteredModule` --inherits--> `ApplicationRecord`  [EXTRACTED]
  app/models/registered_module.rb → app/models/application_record.rb
- `AyayaContract::RunnerTest` --inherits--> `TestCase`  [EXTRACTED]
  test/lib/ayaya_contract/runner_test.rb → test/test_helper.rb
- `RegisteredModuleTest` --inherits--> `TestCase`  [EXTRACTED]
  test/models/registered_module_test.rb → test/test_helper.rb
- `UserTest` --inherits--> `TestCase`  [EXTRACTED]
  test/models/user_test.rb → test/test_helper.rb

## Import Cycles
- None detected.

## Communities (61 total, 17 thin omitted)

### Community 0 - "Ayaya Module Contract v1"
Cohesion: 0.07
Nodes (26): 10. `GET /ayaya/status`, 11. NGINX Routing, 12. Trusted Identity Headers, 13. Local Users, 14. Module Authorization, 15. Database, 16. Deployment Metadata, 17. Background Jobs (+18 more)

### Community 1 - "TestCase"
Cohesion: 0.07
Nodes (13): AyayaContract::RunnerTest, UserTest, AdapterProtocol::ClientTest, AdapterProtocol::ManifestValidatorTest, FakeClient, Modules::RefreshManifestTest, FakeClient, Modules::RefreshStatusTest (+5 more)

### Community 2 - "Client"
Cohesion: 0.10
Nodes (13): AdapterProtocol, Client, Error, InvalidResponse, Unauthorized, Unavailable, Modules, RefreshManifest (+5 more)

### Community 3 - "Ayaya Architecture Constitution"
Cohesion: 0.08
Nodes (24): 10. Module Registry, 11. Manifest Truth, 12. Manifest Snapshot And Refresh, 13. Module State Model, 14. Module Access Policy, 15. Database Ownership, 16. Deployment Discipline, 17. Background Jobs (+16 more)

### Community 4 - "RegisteredModule"
Cohesion: 0.12
Nodes (7): ApplicationController, Base, HomeController, Internal, ModuleAccessController, RegisteredModule, RegisteredModuleTest

### Community 5 - "init_spec.md"
Cohesion: 0.10
Nodes (19): 10. Хранение данных, 11. Scheduler, 12. Интеграции, 13. Развёртывание, 14. Масштабирование, 15. Нефункциональные требования, 16. Предварительная архитектура, 1. Общая информация (+11 more)

### Community 6 - "File Structure"
Cohesion: 0.11
Nodes (17): Ayaya Core Foundation Implementation Plan, File Structure, Global Constraints, Scope Check, Self-Review Checklist, Task 10: Add Contract Test Harness Skeleton, Task 11: Add Static NGINX Example And Operational Notes, Task 12: Final Verification For Core Foundation (+9 more)

### Community 7 - "User"
Cohesion: 0.17
Nodes (4): ApplicationRecord, Base, ModuleUserAccess, User

### Community 8 - "ManifestValidator"
Cohesion: 0.33
Nodes (3): AdapterProtocol, ManifestValidator, Result

### Community 9 - "17. Вопросы для уточнения"
Cohesion: 0.18
Nodes (11): 17. Вопросы для уточнения, API, Kafka, Scheduler, UI, Архитектура, Безопасность, Интеграции (+3 more)

### Community 10 - "Ayaya Project Overview"
Cohesion: 0.18
Nodes (10): Ayaya Project Overview, Core Responsibilities, Core Technology Choices, Explicitly Out Of Scope For Version 1, First Reference Module, Module Responsibilities, Module Technology Choices, Product Shape (+2 more)

### Community 11 - "Runner"
Cohesion: 0.28
Nodes (3): AyayaContract, Result, Runner

### Community 12 - "RefreshStatus"
Cohesion: 0.33
Nodes (3): Modules, RefreshStatus, Result

### Community 13 - "Ayaya Core Foundation Notes"
Cohesion: 0.33
Nodes (5): ActiveAdmin, Ayaya Core Foundation Notes, Foundation Verification, Module Registry, NGINX Static Routing

## Knowledge Gaps
- **120 isolated node(s):** `graphify`, `Internal`, `ApplicationHelper`, `AdapterProtocol`, `AdapterProtocol` (+115 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RegisteredModule` connect `RegisteredModule` to `TestCase`, `Client`, `User`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Why does `Client` connect `Client` to `RefreshStatus`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **What connects `graphify`, `Internal`, `ApplicationHelper` to the rest of the system?**
  _120 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Ayaya Module Contract v1` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `TestCase` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `Client` be split into smaller, more focused modules?**
  _Cohesion score 0.09846153846153846 - nodes in this community are weakly interconnected._
- **Should `Ayaya Architecture Constitution` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._