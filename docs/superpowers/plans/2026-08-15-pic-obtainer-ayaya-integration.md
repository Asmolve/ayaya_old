# Pic Obtainer Ayaya Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `pic_obtainer` an administrator-only Ayaya module with a GUI, Ayaya adapter contract, durable job visibility, and internal Compose deployment.

**Architecture:** Keep `pic_obtainer` as an independently deployable Python application and worker. Add the Ayaya adapter and GUI in that repository, then add only the platform routing, registration, and deployment wiring required in `ayaya`; Core never imports module code, accesses module tables, or executes module jobs.

**Tech Stack:** Python 3.14, FastAPI, Pydantic v2, SQLAlchemy 2 async, PostgreSQL, Alembic, pytest, Docker Compose, Rails, NGINX.

## Global Constraints

- The module key is `pic_obtainer`.
- The first release uses `access.default_policy: admin_only`.
- Domain records remain global in this phase; no `user_id` columns are added.
- Module jobs remain owned and executed by the `pic_obtainer` PostgreSQL worker.
- The API container must not receive Rule34 credentials.
- API and worker ports remain internal-only; user traffic enters through Ayaya NGINX.
- The module exposes `/ayaya/manifest`, `/ayaya/health/live`, `/ayaya/health/ready`, and `/ayaya/status` with bearer-secret authentication.
- Existing facade and durable-job services remain the business boundary; HTTP handlers stay thin.
- Do not add Redis, Celery, WebSockets, or a second queue implementation.
- Preserve the existing Python 3.14 requirement and the existing `pic_obtainer` database/media model.

## Repository map

### `/Users/exsamption/projects/pic_obtainer`

- `src/pic_obtainer/api/main.py` — FastAPI application factory and lifespan.
- `src/pic_obtainer/api/routers/` — thin application API routers.
- `src/pic_obtainer/application/` — facade-backed services.
- `src/pic_obtainer/adapters/postgres/` — repositories, schema mappings, and worker.
- `src/pic_obtainer/worker.py` — worker composition and credential loading.
- `compose.yaml` — PostgreSQL, migration, API, worker, and media volume topology.
- `tests/` — unit, API, and Compose integration coverage.

### `/Users/exsamption/projects/ayaya`

- `compose.yml` — platform Compose services and internal network.
- `deploy/nginx/ayaya.example.conf` — static module routing and trusted identity injection.
- `app/services/modules/` — registration and manifest/status refresh services.
- `app/models/registered_module.rb` — access and runtime state model.
- `test/services/` and `test/lib/ayaya_contract/` — module and contract tests.
- `modules/notes/` — reference module bundle and deployment conventions.

The source of truth for module runtime code remains `pic_obtainer`. The Ayaya repository receives a deployment/reference bundle without copying the Python business package.

---

### Task 1: Define the independent module deployment boundary

**Files:**
- Create: `/Users/exsamption/projects/pic_obtainer/module.yml`
- Create: `/Users/exsamption/projects/pic_obtainer/docs/AYAYA_CONTRACT.md`
- Create: `/Users/exsamption/projects/ayaya/modules/pic_obtainer/README.md`
- Create: `/Users/exsamption/projects/ayaya/modules/pic_obtainer/compose.yml`
- Test: `/Users/exsamption/projects/pic_obtainer/tests/test_module_manifest.py`
- Test: `/Users/exsamption/projects/ayaya/test/lib/ayaya_contract/pic_obtainer_module_test.rb`

**Interfaces:**
- Produces the package manifest consumed by the adapter and the Ayaya deployment descriptor consumed by operators.
- Uses module key `pic_obtainer`, UI path `/m/pic_obtainer`, and API path `/m/pic_obtainer/api`.

- [ ] **Step 1: Write the manifest test** asserting the exact identity, protocol capabilities, routes, and `admin_only` access policy.
- [ ] **Step 2: Run `uv run pytest tests/test_module_manifest.py -q` and verify it fails because `module.yml` is absent.**
- [ ] **Step 3: Add `module.yml` and `docs/AYAYA_CONTRACT.md` documenting the four adapter endpoints, internal-only API, worker-only credentials, and global single-admin data model.**
- [ ] **Step 4: Add the Ayaya module README and deployment descriptor without copying Python business code.**
- [ ] **Step 5: Run the Python manifest test and the Ayaya module contract test; both must pass.**
- [ ] **Step 6: Commit the module-boundary artifacts in each repository with messages `chore: define Ayaya module contract` and `chore: add Pic Obtainer module deployment descriptor`.**

### Task 2: Add the authenticated Ayaya adapter surface

**Files:**
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/ayaya.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/main.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/settings.py`
- Test: `/Users/exsamption/projects/pic_obtainer/tests/api/test_ayaya_adapter.py`

**Interfaces:**
- `GET /ayaya/manifest` returns the parsed package manifest.
- `GET /ayaya/health/live` returns `{"status":"live"}`.
- `GET /ayaya/health/ready` calls `facade.readiness.check()`.
- `GET /ayaya/status` checks readiness and returns safe API/database/worker/media status.
- Every endpoint requires `Authorization: Bearer <PIC_OBTAINER_AYAYA_ADAPTER_SECRET>`.

- [ ] **Step 1: Add failing tests for missing/invalid bearer tokens, manifest equality, readiness failure, and secret-free status payloads.**
- [ ] **Step 2: Run `uv run pytest tests/api/test_ayaya_adapter.py -q` and verify the new contract tests fail.**
- [ ] **Step 3: Implement the adapter router with a constant-time token comparison and a manifest loader shared by package tests and runtime.**
- [ ] **Step 4: Add the adapter secret to explicit API settings without logging or returning its value.**
- [ ] **Step 5: Register the router before the existing `/api/v1` router and preserve the current facade lifespan.**
- [ ] **Step 6: Run `uv run pytest tests/api/test_ayaya_adapter.py tests/api -q`; expect all adapter and existing API tests to pass.**
- [ ] **Step 7: Commit with `feat: expose Ayaya adapter protocol`.**

### Task 3: Add trusted Ayaya identity handling

**Files:**
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/identity.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/main.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/errors.py`
- Test: `/Users/exsamption/projects/pic_obtainer/tests/api/test_ayaya_identity.py`

**Interfaces:**
- `AyayaIdentity` contains `user_id`, `email`, `display_name`, `role`, `module_key`, and `request_id`.
- Middleware reads the six `X-Ayaya-*` headers and stores the identity on `request.state.ayaya_identity`.
- Application routes reject missing/invalid identity with `401` or `403` as appropriate.

- [ ] **Step 1: Write tests for a valid admin identity, missing user id, wrong module key, and client-supplied headers when the request bypasses the internal deployment boundary.**
- [ ] **Step 2: Run `uv run pytest tests/api/test_ayaya_identity.py -q` and verify failure.**
- [ ] **Step 3: Implement typed identity parsing and validation; do not persist identity or add ownership columns in this phase.**
- [ ] **Step 4: Install the middleware and attach safe request-id context to error responses/log records.**
- [ ] **Step 5: Run API tests and verify existing health/validation error envelopes remain unchanged.**
- [ ] **Step 6: Commit with `feat: validate Ayaya trusted identity`.**

### Task 4: Add the server-rendered GUI over the existing facade

**Files:**
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/web.py`
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/templates/base.html`
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/templates/dashboard.html`
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/templates/saved_searches.html`
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/templates/snapshots.html`
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/templates/jobs.html`
- Create: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/static/pic_obtainer.css`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/main.py`
- Test: `/Users/exsamption/projects/pic_obtainer/tests/api/test_web_routes.py`

**Interfaces:**
- `GET /` redirects to or renders the module dashboard.
- `GET /searches` lists saved searches.
- `POST /searches` creates a saved search through `facade.searches.create_rule34`.
- `POST /searches/{id}/retrieve` enqueues `Rule34RetrieveSavedSearchCommand`.
- `GET /snapshots` renders snapshot data obtained through a facade-backed read operation.
- `GET /jobs` and `GET /jobs/{id}` render job status and progress.
- Browser requests are mounted below `/m/pic_obtainer` by deployment configuration; generated links must use the configured root path.

- [ ] **Step 1: Add route tests asserting the dashboard, saved-search creation, retrieval enqueue, and job pages call facade services rather than repositories directly.**
- [ ] **Step 2: Run `uv run pytest tests/api/test_web_routes.py -q` and verify failure.**
- [ ] **Step 3: Implement minimal Jinja-compatible templating using the project’s existing dependency policy; if a template dependency is added, pin it in `pyproject.toml` and `uv.lock`.**
- [ ] **Step 4: Add forms for tags, cid, id, page size, max pages, and max results with server-side Pydantic validation.**
- [ ] **Step 5: Add job polling JavaScript using `GET /api/v1/jobs/{id}` at a bounded interval; render state, progress, cancellation, retry, and safe errors.**
- [ ] **Step 6: Add the dashboard, saved searches, snapshots, and jobs templates with keyboard-accessible forms and no provider secrets.**
- [ ] **Step 7: Run the web-route and full Python test suites.**
- [ ] **Step 8: Commit with `feat: add Pic Obtainer administrator GUI`.**

### Task 5: Make media/import paths safe for the module deployment

**Files:**
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/schemas.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/routers/imports.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/api/routers/media.py`
- Modify: `/Users/exsamption/projects/pic_obtainer/src/pic_obtainer/settings.py`
- Test: `/Users/exsamption/projects/pic_obtainer/tests/api/test_path_policy.py`

**Interfaces:**
- Pinterest import paths must resolve under an explicitly configured import root or the documented mounted path.
- Media downloads continue to use media references and never accept arbitrary filesystem read paths.
- Status exposes free-space/storage incidents without exposing absolute host paths.

- [ ] **Step 1: Add failing tests for an import outside the configured root, a valid mounted import, arbitrary media path rejection, and redacted diagnostics.**
- [ ] **Step 2: Run `uv run pytest tests/api/test_path_policy.py -q` and verify failure.**
- [ ] **Step 3: Add the configured import-root policy and validate paths before creating an import command.**
- [ ] **Step 4: Preserve existing archive size/member/compression limits and media reference validation.**
- [ ] **Step 5: Run focused API, storage, and integration tests.**
- [ ] **Step 6: Commit with `fix: constrain module file access`.**

### Task 6: Align the `pic_obtainer` Compose topology with Ayaya

**Files:**
- Modify: `/Users/exsamption/projects/pic_obtainer/compose.yaml`
- Modify: `/Users/exsamption/projects/pic_obtainer/.env.example`
- Modify: `/Users/exsamption/projects/pic_obtainer/Dockerfile`
- Modify: `/Users/exsamption/projects/pic_obtainer/tests/integration/test_compose.py`
- Modify: `/Users/exsamption/projects/ayaya/modules/pic_obtainer/compose.yml`

**Interfaces:**
- Services are `postgres`, `migrate`, `pic_obtainer_api`, and `pic_obtainer_worker`.
- API and worker use `ayaya_mod_pic_obtainer` through the internal PostgreSQL service.
- The API receives database URL, media root, adapter secret, and import root; the worker additionally receives Rule34 credentials.
- No service publishes a host port except the Ayaya NGINX/Core entrypoint.

- [ ] **Step 1: Extend Compose tests to assert service names, migration gating, internal-only ports, shared media volume, separate database, and API credential absence.**
- [ ] **Step 2: Run `uv run pytest tests/integration/test_compose.py -q` and verify the new assertions fail.**
- [ ] **Step 3: Update Compose anchors and environment variables without embedding real credentials or default host paths.**
- [ ] **Step 4: Add the Ayaya deployment descriptor pointing to the independently built `pic_obtainer` API and worker images/build context.**
- [ ] **Step 5: Run `docker compose config` for both repositories with test-only credentials and verify the rendered topology.**
- [ ] **Step 6: Commit the Python deployment changes and Ayaya deployment descriptor separately.**

### Task 7: Connect the module to Ayaya NGINX and Core registration

**Files:**
- Modify: `/Users/exsamption/projects/ayaya/compose.yml`
- Modify: `/Users/exsamption/projects/ayaya/deploy/nginx/ayaya.example.conf`
- Create: `/Users/exsamption/projects/ayaya/modules/pic_obtainer/docs/REGISTER.md`
- Modify: `/Users/exsamption/projects/ayaya/app/views/home/index.html.erb` only if module presentation needs a platform-safe link adjustment
- Test: `/Users/exsamption/projects/ayaya/test/lib/ayaya_contract/compose_exposure_test.rb`
- Test: `/Users/exsamption/projects/ayaya/test/integration/pic_obtainer_module_test.rb`

**Interfaces:**
- NGINX maps `/m/pic_obtainer` to the internal API service and calls `/internal/auth/module_access` before proxying.
- NGINX injects the trusted six `X-Ayaya-*` headers and strips client-provided copies.
- Core registers the adapter URL and secret, refreshes manifest/status, and enables the module only when healthy.
- Core stores only the adapter secret digest.

- [ ] **Step 1: Add failing Rails/contract tests for the new internal service, no host port exposure, NGINX module route, header allowlist, and admin-only accessibility.**
- [ ] **Step 2: Run `bundle exec rails test test/lib/ayaya_contract/compose_exposure_test.rb test/integration/pic_obtainer_module_test.rb` and verify failure.**
- [ ] **Step 3: Add the internal API/worker service wiring and separate module environment variables to `compose.yml`.**
- [ ] **Step 4: Add static NGINX routing, `auth_request`, internal upstream, and the module path without trusting client-supplied `X-Ayaya-*` headers.**
- [ ] **Step 5: Add registration instructions using the existing Core admin flow and adapter URL reachable on the Compose network.**
- [ ] **Step 6: Run the focused Rails tests and `nginx -t` against the standalone example configuration.**
- [ ] **Step 7: Commit with `feat: connect Pic Obtainer module to Ayaya`.**

### Task 8: Complete contract, end-to-end, and security verification

**Files:**
- Modify: `/Users/exsamption/projects/pic_obtainer/docs/AYAYA_CONTRACT.md`
- Modify: `/Users/exsamption/projects/ayaya/modules/pic_obtainer/README.md`
- Create: `/Users/exsamption/projects/ayaya/test/system/pic_obtainer_module_test.rb`
- Create: `/Users/exsamption/projects/pic_obtainer/tests/integration/test_ayaya_deployment.py`

**Interfaces:**
- The end-to-end flow is admin login → module page → saved search → retrieval job → polled progress → snapshot → media download.
- Failure flow covers disabled module, unhealthy worker, unavailable database, invalid adapter secret, and non-admin access.

- [ ] **Step 1: Add an integration test harness that starts the required Compose services with test-only Rule34 credentials and a temporary media/import directory.**
- [ ] **Step 2: Add tests for adapter contract validation, module registration, NGINX auth, administrator-only access, job polling, cancellation, retry, and safe error rendering.**
- [ ] **Step 3: Run `uv run pytest -q` in `pic_obtainer` and `bundle exec rails test` in `ayaya`; record any environment-only Docker failures separately from code failures.**
- [ ] **Step 4: Run `uv run ruff check .`, `uv run pyright src`, and the Ayaya security/contract checks.**
- [ ] **Step 5: Update module documentation with the exact startup, registration, secret, import-path, and health-refresh commands.**
- [ ] **Step 6: Review the final diff for credentials, absolute host paths, arbitrary file reads, public ports, and duplicated business logic.**
- [ ] **Step 7: Commit documentation and verification coverage with `test: verify Pic Obtainer Ayaya integration`.**

## Verification checklist

Run from `/Users/exsamption/projects/pic_obtainer`:

```bash
uv run pytest -q
uv run ruff check .
uv run pyright src
docker compose config
```

Run from `/Users/exsamption/projects/ayaya`:

```bash
bundle exec rails test
nginx -t -c "$PWD/deploy/nginx/ayaya.example.conf"
docker compose config
```

The implementation is complete only when the acceptance flow in the design document succeeds through Ayaya NGINX and the API container never receives Rule34 credentials.
