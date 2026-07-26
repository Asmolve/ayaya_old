class RegisteredModule < ApplicationRecord
  ADMIN_STATES = %w[registered enabled disabled maintenance].freeze
  RUNTIME_STATUSES = %w[unknown healthy degraded unhealthy unreachable incompatible].freeze
  ACCESS_POLICY_MODES = %w[authenticated admin_only manual].freeze
  MODULE_KEY_PATTERN = /\A[a-z][a-z0-9_]*[a-z0-9]\z/

  has_many :module_user_accesses, dependent: :destroy
  has_many :allowed_users, through: :module_user_accesses, source: :user

  validates :module_key, presence: true, uniqueness: true, format: { with: MODULE_KEY_PATTERN }
  validates :name, :version, :adapter_url, :adapter_secret_digest, :adapter_protocol_version, presence: true
  validates :admin_state, inclusion: { in: ADMIN_STATES }
  validates :runtime_status, inclusion: { in: RUNTIME_STATUSES }
  validates :access_policy_mode, inclusion: { in: ACCESS_POLICY_MODES }

  def enabled_for_users?
    admin_state == "enabled" && %w[healthy degraded].include?(runtime_status)
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
end
