require "yaml"

module AyayaContract
  class ManifestLoader
    def self.load_file(path)
      YAML.safe_load_file(path, aliases: false)
    end
  end
end
