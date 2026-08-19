Rails.application.routes.draw do
  scope "/m/planning" do
    root "workspace#show", as: :planning_root
    resources :plans, only: %i[show create edit update destroy], constraints: { id: /\d+/ }
    resources :plan_items, only: %i[show create edit update destroy], constraints: { id: /\d+/ }
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
