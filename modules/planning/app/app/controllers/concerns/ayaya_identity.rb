module AyayaIdentity
  extend ActiveSupport::Concern

  included do
    before_action :require_ayaya_identity
    helper_method :current_local_user
  end

  private

  attr_reader :current_local_user

  def require_ayaya_identity
    return head :unauthorized if request.headers["X-Ayaya-User-Id"].blank?
    return head :unauthorized unless request.headers["X-Ayaya-Module-Key"] == "planning"

    @current_local_user = find_or_create_local_user(request.headers["X-Ayaya-User-Id"])
    @current_local_user.assign_attributes(identity_attributes.merge(last_seen_at: Time.current))
    @current_local_user.save!
  end

  def identity_attributes
    {
      email: request.headers["X-Ayaya-User-Email"],
      display_name: request.headers["X-Ayaya-User-Display-Name"],
      global_role: request.headers["X-Ayaya-User-Role"]
    }.compact_blank
  end

  def find_or_create_local_user(core_user_id)
    LocalUser.create_or_find_by!(core_user_id: core_user_id)
  rescue ActiveRecord::RecordInvalid => error
    raise unless error.record.errors.details[:core_user_id].any? { |detail| detail[:error] == :taken }

    LocalUser.find_by!(core_user_id: core_user_id)
  end
end
