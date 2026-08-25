module AyayaIdentity
  extend ActiveSupport::Concern

  included do
    before_action :require_ayaya_identity
    prepend_before_action :reject_cross_site_mutation
    helper_method :current_module_user
  end

  private

  attr_reader :current_module_user

  def require_ayaya_identity
    core_user_id = request.headers["X-Ayaya-User-Id"]
    return head :unauthorized if core_user_id.blank? || request.headers["X-Ayaya-Module-Key"] != "telegram" || !Telegram::TrustedIdentity.valid?(request)

    @current_module_user = find_or_create_module_user(core_user_id)
    @current_module_user.update!(identity_attributes.merge(last_seen_at: Time.current))
  end

  def identity_attributes
    {
      email: request.headers["X-Ayaya-User-Email"],
      display_name: request.headers["X-Ayaya-User-Display-Name"],
      global_role: request.headers["X-Ayaya-User-Role"]
    }.compact_blank
  end

  def find_or_create_module_user(core_user_id)
    ModuleUser.create_or_find_by!(core_user_id: core_user_id)
  rescue ActiveRecord::RecordInvalid => error
    raise unless error.record.errors.details[:core_user_id].any? { |detail| detail[:error] == :taken }

    ModuleUser.find_by!(core_user_id: core_user_id)
  end
end
