class PlanItemsController < ApplicationController
  include AyayaIdentity

  before_action :set_plan_item, only: %i[show edit update destroy position]

  def show
    redirect_to planning_root_path(plan_id: @plan_item.plan_id)
  end

  def create
    @plan = current_local_user.plans.find(plan_item_params.fetch(:plan_id))
    attributes = plan_item_params.to_h.symbolize_keys.except(:plan_id, :position)
    @plan_item = @plan.plan_items.build(attributes)
    @plan_item.position = @plan.plan_items.where(priority: @plan_item.priority).count

    if @plan_item.save
      redirect_to planning_root_path(plan_id: @plan.id)
    else
      @plan = Plan.new
      prepare_workspace(@plan_item.plan)
      render "workspace/show", status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def edit
  end

  def update
    attributes = plan_item_params.to_h.symbolize_keys.except(:plan_id)
    @plan_item.assign_attributes(attributes.except(:priority, :position))

    if @plan_item.valid?
      ActiveRecord::Base.transaction do
        @plan_item.save!
        reposition(@plan_item, attributes) if ordering_attributes?(attributes)
      end
      redirect_to planning_root_path(plan_id: @plan_item.plan_id)
    else
      render :edit, status: :unprocessable_entity
    end
  rescue PlanItemPositioner::InvalidPayload => error
    render_position_errors(error.errors)
  end

  def destroy
    plan_id = @plan_item.plan_id
    @plan_item.destroy!
    redirect_to planning_root_path(plan_id: plan_id)
  end

  def position
    item = PlanItemPositioner.new(@plan_item, **position_params).call

    respond_to do |format|
      format.json { render json: position_payload(item) }
      format.html { redirect_to planning_root_path(plan_id: item.plan_id) }
    end
  rescue PlanItemPositioner::InvalidPayload => error
    render_position_errors(error.errors)
  end

  private

  def set_plan_item
    @plan_item = current_local_user.plan_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    if request.format.json?
      render json: { error: "not_found" }, status: :not_found
    else
      head :not_found
    end
  end

  def plan_item_params
    params.require(:plan_item).permit(:plan_id, :title, :notes, :priority, :position, :completed)
  end

  def position_params
    payload = params.permit(:priority, :position)
    { priority: payload[:priority], position: position_value(payload[:position]) }
  end

  def ordering_attributes?(attributes)
    attributes.key?(:priority) || attributes.key?(:position)
  end

  def reposition(item, attributes)
    PlanItemPositioner.new(
      item,
      priority: attributes.fetch(:priority, item.priority),
      position: position_value(attributes.fetch(:position, item.position))
    ).call
  end

  def position_value(value)
    return value if value.is_a?(Integer)
    return Integer(value, 10) if value.is_a?(String) && value.match?(/\A\d+\z/)

    value
  end

  def position_payload(item)
    item.slice(:id, :plan_id, :title, :priority, :position, :completed)
  end

  def render_position_errors(errors)
    respond_to do |format|
      format.json { render json: { errors: errors }, status: :unprocessable_entity }
      format.html do
        errors.each { |error| @plan_item.errors.add(:base, error) }
        prepare_workspace(@plan_item.plan)
        render "workspace/show", status: :unprocessable_entity
      end
    end
  end
end
