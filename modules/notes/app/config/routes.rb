Rails.application.routes.draw do
  scope "/m/notes" do
    root "notes#index", as: :notes_root
    get "diary", to: "diary#index", as: :diary
    get "diary/entry", to: "diary#entry", defaults: { format: :json }
    resources :notes
  end

  namespace :internal do
    namespace :ayaya do
      get "status", to: "status#show"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
