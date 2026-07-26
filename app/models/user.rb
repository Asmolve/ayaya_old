class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLES = %w[user admin].freeze

  validates :role, inclusion: { in: ROLES }
  validates :display_name, length: { maximum: 120 }

  before_validation :default_display_name

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }

  def admin?
    role == "admin"
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive
  end

  private

  def default_display_name
    self.display_name = email.to_s.split("@").first if display_name.blank? && email.present?
  end
end
