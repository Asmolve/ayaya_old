# Pic Obtainer module

This directory contains the Ayaya deployment descriptor for the independently
maintained `/Users/exsamption/projects/pic_obtainer` module. The Python package,
FastAPI application, worker, migrations, and module adapter remain owned by the
Pic Obtainer repository and are not copied into Ayaya.

The module is registered under `pic_obtainer` and is available to Ayaya admins at
`/m/pic_obtainer`. Core communicates with the module only through the adapter
contract; module business logic and durable jobs remain outside Core.

Use [`compose.yml`](compose.yml) as the Ayaya deployment reference. Configure
the image or build context for the Pic Obtainer repository before starting the
platform.
