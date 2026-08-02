# Register Notes In Core

1. Start the platform with `docker compose up --build`.
2. Open Core admin at `/admin`. If no modules are registered, select **Register the local Notes adapter**.
3. Open `/admin/registered_modules`, select Notes, use **Refresh manifest** and **Refresh status**, then select **Enable** once the module is healthy.
4. Adjust the access policy or allowed users if needed.

Rails runner commands remain available as fallback diagnostics:

```bash
docker compose exec core bin/rails runner 'result = Modules::RegisterAdapter.call(adapter_url: "http://notes_adapter:8080", adapter_secret: "development-notes-adapter-secret"); abort(result.errors.join("; ")) unless result.success?; puts "Registered #{result.registered_module.module_key}"'
```

The older low-level sequence is:

```bash
docker compose exec core bin/rails runner 'registered_module = RegisteredModule.find_by!(module_key: "notes"); result = Modules::RefreshManifest.call(registered_module: registered_module, adapter_secret: "development-notes-adapter-secret"); abort(result.errors.join("; ")) unless result.success?; puts "Manifest refreshed"'
```

```bash
docker compose exec core bin/rails runner 'registered_module = RegisteredModule.find_by!(module_key: "notes"); result = Modules::RefreshStatus.call(registered_module: registered_module, adapter_secret: "development-notes-adapter-secret"); abort(result.errors.join("; ")) unless result.success?; puts "Status refreshed: #{result.registered_module.runtime_status}"'
```

5. Open `/m/notes` through NGINX.

Core stores only `adapter_secret_digest` for the registered module. Pass the plaintext adapter secret again whenever running the manifest or status refresh commands. If the module is already registered, skip the registration command and run the two refresh commands.

The adapter URL is reachable from Core over the internal Compose network. Do not publish `notes_adapter` to the host to perform registration or contract checks.
