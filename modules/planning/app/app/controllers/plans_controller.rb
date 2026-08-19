class PlansController < ApplicationController
  include AyayaIdentity

  before_action :set_plan, only: %i[show edit update destroy]

  def show
    redirect_to planning_root_path(plan_id: @plan.id)
  end

  def new
    @plan = current_local_user.plans.build
  end

  def create
    @plan = current_local_user.plans.build(plan_params)

    if @plan.save
      redirect_to planning_root_path(plan_id: @plan.id)
    else
      prepare_workspace
      render "workspace/show", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to planning_root_path(plan_id: @plan.id)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plan.destroy!
    redirect_to planning_root_path
  end

  private

  def set_plan
    @plan = current_local_user.plans.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def plan_params
    params.require(:plan).permit(:title)
  end
end
