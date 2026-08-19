Rails.application.routes.draw do
  scope "/m/planning" do
    root "workspace#show", as: :planning_root
    resources :plans
    resources :plan_items
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
