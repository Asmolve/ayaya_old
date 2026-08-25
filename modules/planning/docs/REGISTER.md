# Register Planning In Core

Set `PLANNING_ADAPTER_SECRET` to the same externally managed value for Core and `planning_adapter`. Once the bundle is running, register or refresh the adapter through the existing Core module administration workflow, then enable the module when its adapter status is healthy.

Core communicates with the adapter over the private Compose network; do not publish `planning_adapter` to the host for registration.
