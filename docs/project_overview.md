# Ayaya Project Overview

## Purpose

Ayaya is a self-hosted modular web platform that brings independent user-facing services under one entry point, one identity system, and one platform administration model.

The project has two equally important goals:

- provide a practical personal platform for building useful services;
- define strict module contracts so that future modules can be implemented independently, including by AI agents, without requiring access to Core internals.

Ayaya is not intended to become a public marketplace or a fully untrusted plugin platform in the first version. Modules are treated as internal trusted services, but they must still integrate through explicit platform contracts.

## Product Shape

The platform consists of:

- Core, the central Rails application;
- NGINX, the public entry point and routing/auth boundary;
- independent modules, each with its own application, adapter, and database;
- a mandatory Module Adapter Protocol used by Core to understand each module;
- a first reference module, `notes`, used to validate the architecture.

The first version should prove the full vertical flow:

```text
Core login -> NGINX auth_request -> Notes UI -> Notes DB
Core admin -> Notes Adapter -> manifest/status
```

## Core Responsibilities

Core owns platform-level concerns:

- user registration and authentication;
- server-side web sessions;
- global user roles;
- module registry;
- module access policies;
- adapter registration;
- manifest snapshots;
- module runtime status snapshots;
- platform navigation;
- platform unavailable/forbidden pages;
- Core administration through ActiveAdmin.

Core does not contain module business logic.

## Module Responsibilities

Each module is a standalone application. A module owns:

- its backend;
- its frontend;
- its domain model;
- its local authorization rules;
- its local user records;
- its own database;
- its own migrations;
- its external integrations;
- its background jobs;
- its deployment process.

Modules do not access Core tables or other module databases directly.

## First Reference Module

The first reference module is `notes`.

The `notes` module should include:

- route namespace `/m/notes`;
- a module adapter;
- a separate database named `ayaya_mod_notes`;
- note listing;
- note creation;
- note viewing;
- note editing;
- note deletion;
- lazy local user records based on trusted platform headers;
- domain authorization where users can access only their own notes;
- contract tests for its module bundle and adapter.

## Core Technology Choices

Core uses:

- Ruby on Rails;
- Devise for authentication;
- ActiveAdmin for administration;
- PostgreSQL for Core persistence;
- secure cookie-backed web sessions;
- Rails views for the simple platform UI.

ActiveAdmin is only for Core administration. It is not a module UI framework and must not absorb module business logic into Core.

## Module Technology Choices

Modules may use different implementation stacks if they satisfy the Module Contract v1.

The platform does not require modules to use Rails, Ruby, or a shared frontend framework. The stable boundary is the Adapter Protocol and the deployment/module bundle contract.

## Version 1 Scope

Version 1 includes:

- Rails Core;
- Devise authentication;
- one `User` model with `user` and `admin` roles;
- ActiveAdmin for Core admin;
- module registry;
- adapter registration by URL and shared secret;
- manifest snapshot and refresh;
- health/status refresh;
- module access policy;
- NGINX `auth_request`;
- trusted identity headers;
- static NGINX routes;
- module bundle standard;
- module contract tests;
- the `notes` reference module;
- separate database per module inside a shared PostgreSQL instance.

## Explicitly Out Of Scope For Version 1

Version 1 does not include:

- platform deployer;
- dynamic NGINX config generation;
- runtime event bus;
- Kafka;
- service-to-service runtime implementation;
- shared external integration vault;
- workspace or organization model;
- public module marketplace;
- hard user deletion or cross-module data erasure;
- module lifecycle commands from Core;
- polished unified frontend shell;
- iframe or microfrontend composition;
- module SDK or generator CLI.

These items may be designed later once real module use cases justify them.

