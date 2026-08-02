module Modules
  class RegisterReferenceNotes
    def self.adapter_url
      ENV.fetch("NOTES_ADAPTER_URL")
    end

    def self.adapter_secret
      ENV.fetch("NOTES_ADAPTER_SECRET")
    end

    def self.call
      existing = RegisteredModule.find_by(module_key: "notes")
      return RegisterAdapter::Result.new(success?: true, registered_module: existing, errors: []) if existing

      RegisterAdapter.call(adapter_url: adapter_url, adapter_secret: adapter_secret)
    end
  end
end
