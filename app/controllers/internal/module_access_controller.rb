module Internal
  class ModuleAccessController < ApplicationController
    before_action :force_non_navigational_format, prepend: true
    before_action :authenticate_user!

    def show
      module_key = extract_module_key(request.headers["X-Original-URI"].to_s)
      return head :forbidden if module_key.blank?

      registered_module = RegisteredModule.find_by(module_key:)
      return head :forbidden unless registered_module
      return head :service_unavailable unless %w[healthy degraded].include?(registered_module.runtime_status)
      return head :forbidden unless registered_module.accessible_by?(current_user)

      response.headers["X-Ayaya-User-Id"] = current_user.id.to_s
      response.headers["X-Ayaya-User-Email"] = current_user.email
      response.headers["X-Ayaya-User-Display-Name"] = current_user.display_name
      response.headers["X-Ayaya-User-Role"] = current_user.role
      response.headers["X-Ayaya-Module-Key"] = registered_module.module_key
      response.headers["X-Ayaya-Request-Id"] = request.request_id
      head :no_content
    end

    private

    def force_non_navigational_format
      request.format = :json
    end

    def extract_module_key(original_uri)
      match = original_uri.match(%r{\A/m/([a-z][a-z0-9_]*[a-z0-9])(?:/|\z)})
      match && match[1]
    end
  end
end
