class PlanItemPositioner
  class InvalidPayload < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.join(", "))
    end
  end

  def initialize(plan_item, priority:, position:)
    @plan_item = plan_item
    @priority = priority
    @position = position
  end

  def call
    validate_payload!

    @plan_item.plan.with_lock do
      items_by_priority = @plan_item.plan.plan_items.lock.order(:id).to_a.group_by(&:priority)
      PlanItem.priorities.each_key { |priority| items_by_priority[priority] ||= [] }

      items_by_priority.fetch(@plan_item.priority).delete(@plan_item)
      destination = items_by_priority.fetch(@priority)
      destination.insert([ @position, destination.length ].min, @plan_item)

      items_by_priority.each do |priority, items|
        items.each_with_index do |item, index|
          next if item.priority == priority && item.position == index

          item.update_columns(priority: priority, position: index, updated_at: Time.current)
        end
      end
    end

    @plan_item.reload
  end

  private

  def validate_payload!
    errors = []
    errors << "Priority is invalid" unless PlanItem.priorities.key?(@priority)
    errors << "Position must be a non-negative integer" unless @position.is_a?(Integer) && @position >= 0
    raise InvalidPayload, errors if errors.any?
  end
end
