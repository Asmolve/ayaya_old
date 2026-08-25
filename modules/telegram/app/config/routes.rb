Rails.application.routes.draw do
  scope "/m/telegram" do
    root "dashboard#show", as: :telegram_root
    post "imports", to: "imports#create", as: :telegram_imports
    post "accounts/connect", to: "accounts#connect", as: :telegram_connect
    post "accounts/code", to: "accounts#submit_code", as: :telegram_submit_code
    post "accounts/password", to: "accounts#submit_password", as: :telegram_submit_password
    post "accounts/qr", to: "accounts#start_qr", as: :telegram_start_qr
    post "accounts/qr/poll", to: "accounts#poll_qr", as: :telegram_poll_qr
    post "accounts/read-only", to: "accounts#update_read_only", as: :telegram_read_only
    post "operations/:id/apply", to: "operations#apply", as: :telegram_apply_operation
    get "operations/:id", to: "operations#show", as: :telegram_operation
    post "operations/dry-run", to: "operations#dry_run", as: :telegram_dry_run
    post "operations/:id/cancel", to: "operations#cancel", as: :telegram_cancel_operation
    post "operations/:id/rollback", to: "operations#rollback", as: :telegram_rollback_operation
    post "rules", to: "rules#create", as: :telegram_rules
    patch "rules/:id", to: "rules#update", as: :telegram_rule
    post "assignments", to: "assignments#create", as: :telegram_assignments
    post "assignments/bulk", to: "assignments#bulk", as: :telegram_bulk_assignments
    patch "assignments/:id", to: "assignments#update", as: :telegram_assignment
    patch "assignments/:id/review", to: "assignments#review", as: :telegram_review_assignment
    post "folder-proposals/:id/accept", to: "folder_proposals#accept", as: :telegram_accept_folder_proposal
    post "accounts/:id/disconnect", to: "accounts#disconnect", as: :telegram_disconnect_account
  end

  namespace :internal do
    namespace :ayaya do
      get "status", to: "status#show"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
