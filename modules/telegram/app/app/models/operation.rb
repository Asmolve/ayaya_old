class Operation < ApplicationRecord
  STATUSES = %w[planned awaiting_confirmation applying reconciling completed failed conflicted cancelled].freeze

  belongs_to :telegram_account, inverse_of: :operations
  belongs_to :before_snapshot, class_name: "Snapshot", optional: true
  has_many :operation_steps, dependent: :destroy, inverse_of: :operation

  validates :operation_id, :status, presence: true
  validates :operation_id, uniqueness: { scope: :telegram_account_id }
  validates :status, inclusion: { in: STATUSES }
  validate :before_snapshot_belongs_to_account
  before_validation :encrypt_plan
  before_validation :set_retention, on: :create

  def transition_to!(status)
    raise ArgumentError, "invalid operation status" unless STATUSES.include?(status)

    update!(status: status, completed_at: %w[completed failed conflicted cancelled].include?(status) ? Time.current : nil)
  end

  def plan_data(key_provider: Telegram::KeyProvider.from_environment)
    return Telegram::Redactor.call(plan) unless Telegram::EncryptedPayload.envelope?(plan)

    Telegram::EncryptedPayload.decrypt(plan, key_provider:)
  end

  def latest_successful_for_account?
    status == "completed" && telegram_account.operations.where(status: "completed").order(completed_at: :desc, id: :desc).first&.id == id
  end

  def request_execution!(now: Time.current)
    raise ArgumentError, "operation is not awaiting confirmation" unless status == "awaiting_confirmation"

    update!(execution_requested_at: now, next_attempt_at: now)
  end

  private

  def encrypt_plan
    self.plan = Telegram::EncryptedPayload.encrypt(plan) unless Telegram::EncryptedPayload.envelope?(plan)
  end

  def set_retention
    self.retention_until ||= 30.days.from_now
  end

  def before_snapshot_belongs_to_account
    errors.add(:before_snapshot, "must belong to the same Telegram account") if before_snapshot && before_snapshot.telegram_account_id != telegram_account_id
  end
end
