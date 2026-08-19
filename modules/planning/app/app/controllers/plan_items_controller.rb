class PlanItemsController < ApplicationController
  include AyayaIdentity

  before_action :set_plan_item, only: %i[show edit update destroy]

  def show
    redirect_to planning_root_path(plan_id: @plan_item.plan_id)
  end

  def create
    @plan = current_local_user.plans.find(plan_item_params.fetch(:plan_id))
    @plan_item = @plan.plan_items.build(plan_item_params.except(:plan_id))

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
    if @plan_item.update(plan_item_params.except(:plan_id))
      redirect_to planning_root_path(plan_id: @plan_item.plan_id)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    plan_id = @plan_item.plan_id
    @plan_item.destroy!
    redirect_to planning_root_path(plan_id: plan_id)
  end

  private

  def set_plan_item
    @plan_item = current_local_user.plan_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def plan_item_params
    params.require(:plan_item).permit(:plan_id, :title, :notes, :priority, :position, :completed)
  end
end
