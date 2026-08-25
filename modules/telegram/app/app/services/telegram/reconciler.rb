module Telegram
  class Reconciler
    def initialize(client:)
      @client = client
    end

    def reconcile(step)
      expected = stringify(step.expected_postcondition)
      state = stringify(@client.read_state)
      result = StateComparison.equivalent?(state, expected) ? :confirmed : :outcome_unknown
      return result unless step.respond_to?(:update!)

      if result == :confirmed
        step.update!(status: "confirmed", result_fingerprint: CanonicalSnapshot.build(state: state).source_hash)
        operation = step.operation
        operation.transition_to!("completed") if operation.operation_steps.where.not(status: "confirmed").none?
      else
        step.update!(status: "outcome_unknown")
        step.operation.transition_to!("reconciling")
      end
      result
    end

    private

    def stringify(value)
      value.deep_stringify_keys
    end
  end
end
