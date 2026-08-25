module Internal
  module Ayaya
    class StatusController < ApplicationController
      skip_forgery_protection
      before_action :require_internal_secret

      def show
        ActiveRecord::Base.connection.execute("SELECT 1")
        key_status = Telegram::KeyProvider.available? ? "healthy" : "unhealthy"
        status = key_status == "healthy" ? "healthy" : "unhealthy"
        render json: payload(status, key_status), status: status == "healthy" ? :ok : :service_unavailable
      rescue ActiveRecord::ActiveRecordError
        render json: payload("unhealthy", "unknown", database: "unhealthy", reasons: [ "database_unavailable" ]), status: :service_unavailable
      end

      private

      def require_internal_secret
        expected = ENV.fetch("TELEGRAM_INTERNAL_STATUS_SECRET", "")
        token = request.authorization.to_s.delete_prefix("Bearer ")
        valid = expected.present? && token.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(token, expected)
        head :unauthorized unless valid
      end

      def payload(runtime_status, key_status, database: "healthy", reasons: [])
        { module_key: "telegram", runtime_status: runtime_status,
          components: { app: "healthy", database: database, key_management: key_status, telegram: "degraded" },
          checked_at: Time.current.utc.iso8601, degraded_reasons: reasons }.tap { |body| body[:degraded_reasons] << "telegram_not_checked" if runtime_status == "healthy" }
      end
    end
  end
end
