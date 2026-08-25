class WorkspaceController < ApplicationController
  include AyayaIdentity

  def show
    prepare_workspace
    return if params[:plan_id].blank?

    @selected_plan = @plans.find(params[:plan_id])
    @plan_item = @selected_plan.plan_items.build
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
