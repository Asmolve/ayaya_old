class RegisteredModule < ApplicationRecord
  ADMIN_STATES = %w[registered enabled disabled maintenance].freeze
  RUNTIME_STATUSES = %w[unknown healthy degraded unhealthy unreachable incompatible].freeze
  ACCESS_POLICY_MODES = %w[authenticated admin_only manual].freeze
  USER_AVAILABLE_RUNTIME_STATUSES = %w[healthy degraded].freeze
  MODULE_KEY_PATTERN = /\A[a-z][a-z0-9_]*[a-z0-9]\z/

  has_many :module_user_accesses, dependent: :destroy
  has_many :allowed_users, through: :module_user_accesses, source: :user

  validates :module_key, presence: true, uniqueness: true, format: { with: MODULE_KEY_PATTERN }
  validates :name, :version, :adapter_url, :adapter_secret_digest, :adapter_protocol_version, presence: true
  validates :admin_state, inclusion: { in: ADMIN_STATES }
  validates :runtime_status, inclusion: { in: RUNTIME_STATUSES }
  validates :access_policy_mode, inclusion: { in: ACCESS_POLICY_MODES }

  def enabled_for_users?
    user_available?
  end

  def user_available?
    admin_state == "enabled" && USER_AVAILABLE_RUNTIME_STATUSES.include?(runtime_status)
  end

  def ready_to_enable?
    admin_state == "registered" && USER_AVAILABLE_RUNTIME_STATUSES.include?(runtime_status)
  end

  def availability_label
    return "available" if user_available?
    return "ready to enable" if ready_to_enable?
    return "maintenance" if admin_state == "maintenance"
    return "disabled" if admin_state == "disabled"

    "needs attention"
  end

  def availability_blocker
    return "Users can access this module." if user_available?
    return "Module is registered and healthy. Enable it to make it available." if ready_to_enable?
    return maintenance_reason.presence || "Module is in maintenance mode." if admin_state == "maintenance"
    return "Module is disabled by an admin." if admin_state == "disabled"
    return "Module runtime is #{runtime_status}. Refresh status or fix the module service." unless USER_AVAILABLE_RUNTIME_STATUSES.include?(runtime_status)

    "Module is not enabled for users."
  end

  def accessible_by?(user)
    return false unless user&.active?
    return false unless enabled_for_users?
    return true if user.admin?

    case access_policy_mode
    when "authenticated"
      true
    when "admin_only"
      false
    when "manual"
      allowed_users.exists?(user.id)
    else
      false
    end
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      access_policy_mode
      adapter_protocol_version
      adapter_url
      admin_state
      created_at
      id
      last_manifest_refreshed_at
      last_status_refreshed_at
      maintenance_reason
      module_key
      name
      runtime_status
      updated_at
      version
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
