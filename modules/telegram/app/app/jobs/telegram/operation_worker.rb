module Telegram
  class OperationWorker < ::ApplicationJob
    queue_as :default

    def perform(operation_id)
      operation = Operation.find_by(operation_id:)
      return unless operation
      return unless operation.status == "awaiting_confirmation" && operation.execution_requested_at.present?

      WorkerService.new.tick
    end
  end
end
