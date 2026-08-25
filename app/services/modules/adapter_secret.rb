module Modules
  module AdapterSecret
    module_function

    def for(registered_module)
      case registered_module.module_key
      when "notes"
        Modules::RegisterReferenceNotes.adapter_secret if registered_module.adapter_url == Modules::RegisterReferenceNotes.adapter_url
      when "pic_obtainer"
        ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"].presence
      when "planning"
        ENV["PLANNING_ADAPTER_SECRET"].presence
      when "telegram"
        ENV["TELEGRAM_ADAPTER_SECRET"].presence if registered_module.adapter_url == ENV["TELEGRAM_ADAPTER_URL"]
      end
    end
  end
end
