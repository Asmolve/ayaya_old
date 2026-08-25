class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  private

  def prepare_workspace(selected_plan = nil)
    @plans = current_local_user.plans.order(:created_at)
    @selected_plan = selected_plan || @plans.first
    @plan ||= current_local_user.plans.build
    @plan_item ||= @selected_plan&.plan_items&.build || PlanItem.new
  end
end
