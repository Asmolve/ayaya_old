# Planning Module App

The Rails application for Ayaya's `planning` module. Run migrations with `bin/rails db:prepare`; the adapter-only database health endpoint is `GET /internal/ayaya/status` and requires `PLANNING_INTERNAL_STATUS_SECRET` as a bearer token.
