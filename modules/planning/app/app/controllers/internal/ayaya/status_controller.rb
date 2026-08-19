module Internal
  module Ayaya
    class StatusController < ApplicationController
      skip_forgery_protection
      before_action :require_internal_secret

      def show
        ActiveRecord::Base.connection.execute("SELECT 1")
        render json: status_payload(runtime_status: "healthy", database_status: "healthy", degraded_reasons: [])
      rescue ActiveRecord::ActiveRecordError
        render json: status_payload(
          runtime_status: "unhealthy",
          database_status: "unhealthy",
          degraded_reasons: [ "database_unavailable" ]
        ), status: :service_unavailable
      end

      private

      def require_internal_secret
        expected = ENV.fetch("PLANNING_INTERNAL_STATUS_SECRET", "")
        token = request.authorization.to_s.delete_prefix("Bearer ")
        valid = expected.present? && token.bytesize == expected.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(token, expected)

        head :unauthorized unless valid
      end

      def status_payload(runtime_status:, database_status:, degraded_reasons:)
        {
          module_key: "planning",
          runtime_status: runtime_status,
          components: { app: "healthy", database: database_status },
          checked_at: Time.current.utc.iso8601,
          degraded_reasons: degraded_reasons
        }
      end
    end
  end
end
