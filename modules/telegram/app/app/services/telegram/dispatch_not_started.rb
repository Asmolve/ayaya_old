require "timeout"

module Telegram
  class DispatchNotStarted < Timeout::Error; end
end
