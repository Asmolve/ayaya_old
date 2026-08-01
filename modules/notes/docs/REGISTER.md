# Register Notes In Core

1. Start the platform with `docker compose up --build`.
2. Register the adapter from the Core container with `Modules::RegisterAdapter`:

   ```bash
   docker compose exec core bin/rails runner 'result = Modules::RegisterAdapter.call(adapter_url: "http://notes_adapter:8080", adapter_secret: "development-notes-adapter-secret"); abort(result.errors.join("; ")) unless result.success?; puts "Registered #{result.registered_module.module_key}"'
   ```

3. Refresh the manifest with `Modules::RefreshManifest`:

   ```bash
   docker compose exec core bin/rails runner 'registered_module = RegisteredModule.find_by!(module_key: "notes"); result = Modules::RefreshManifest.call(registered_module: registered_module, adapter_secret: "development-notes-adapter-secret"); abort(result.errors.join("; ")) unless result.success?; puts "Manifest refreshed"'
   ```

4. Refresh runtime status with `Modules::RefreshStatus`:

   ```bash
   docker compose exec core bin/rails runner 'registered_module = RegisteredModule.find_by!(module_key: "notes"); result = Modules::RefreshStatus.call(registered_module: registered_module, adapter_secret: "development-notes-adapter-secret"); abort(result.errors.join("; ")) unless result.success?; puts "Status refreshed: #{result.registered_module.runtime_status}"'
   ```

5. Open Core admin at `/admin/registered_modules`. ActiveAdmin does not register adapters or refresh manifests/status. Use it only to set `admin_state` to `enabled` and adjust the access policy or allowed users if needed.
6. Open `/m/notes` through NGINX.

Core stores only `adapter_secret_digest` for the registered module. Pass the plaintext adapter secret again whenever running the manifest or status refresh commands. If the module is already registered, skip the registration command and run the two refresh commands.

The adapter URL is reachable from Core over the internal Compose network. Do not publish `notes_adapter` to the host to perform registration or contract checks.
