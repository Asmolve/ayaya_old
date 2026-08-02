module Modules
  class RegisterReferenceNotes
    ADAPTER_URL = "http://notes_adapter:8080"
    ADAPTER_SECRET = "development-notes-adapter-secret"

    def self.call
      existing = RegisteredModule.find_by(module_key: "notes")
      return RegisterAdapter::Result.new(success?: true, registered_module: existing, errors: []) if existing

      RegisterAdapter.call(adapter_url: ADAPTER_URL, adapter_secret: ADAPTER_SECRET)
    end
  end
end
