require "net/http"
require "json"

module AdapterProtocol
  class Client
    class Error < StandardError; end
    class Unauthorized < Error; end
    class Unavailable < Error; end
    class InvalidResponse < Error; end

    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 5

    def initialize(adapter_url:, adapter_secret:)
      @adapter_uri = URI(adapter_url)
      @adapter_secret = adapter_secret
    end

    def manifest
      get_json("/ayaya/manifest")
    end

    def status
      get_json("/ayaya/status")
    end

    private

    attr_reader :adapter_uri, :adapter_secret

    def get_json(path)
      uri = adapter_uri + path
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{adapter_secret}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 401, 403
        raise Unauthorized, "adapter rejected Core credentials"
      else
        raise Unavailable, "adapter returned HTTP #{response.code}"
      end
    rescue JSON::ParserError => e
      raise InvalidResponse, e.message
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Unavailable, e.message
    end
  end
end
