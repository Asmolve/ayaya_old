class OperationStep < ApplicationRecord
  STATUSES = %w[planned dispatched outcome_unknown confirmed failed cancelled].freeze

  RPCS = %w[update_dialog_filter update_dialog_filters_order].freeze

  belongs_to :telegram_account, inverse_of: :operation_steps
  belongs_to :operation, inverse_of: :operation_steps

  validates :step_id, :request_fingerprint, :precondition_fingerprint, :rpc, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rpc, inclusion: { in: RPCS }
  validates :sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :operation_id }
  validates :step_id, uniqueness: { scope: %i[telegram_account_id operation_id] }
  validate :operation_belongs_to_account
  before_validation :assign_sequence, on: :create
  before_validation :encrypt_request

  def request_data(key_provider: Telegram::KeyProvider.from_environment)
    return Telegram::Redactor.call(request_payload) unless Telegram::EncryptedPayload.envelope?(request_payload)

    Telegram::EncryptedPayload.decrypt(request_payload, key_provider:)
  end

  private

  def operation_belongs_to_account
    errors.add(:operation, "must belong to the same Telegram account") if operation && operation.telegram_account_id != telegram_account_id
  end

  def encrypt_request
    self.request_payload = Telegram::EncryptedPayload.encrypt(request_payload) unless Telegram::EncryptedPayload.envelope?(request_payload)
  end

  def assign_sequence
    return unless operation_id && (sequence.nil? || sequence.zero?)

    max_sequence = operation.operation_steps.where.not(id:).maximum(:sequence)
    self.sequence = max_sequence ? max_sequence + 1 : 0
  end
end
