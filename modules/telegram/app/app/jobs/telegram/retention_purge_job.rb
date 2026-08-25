module Telegram
  class RetentionPurgeJob < ::ApplicationJob
    queue_as :low_priority

    def perform
      RetentionPurge.new.call
    end
  end
end
