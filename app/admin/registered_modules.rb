ActiveAdmin.register RegisteredModule do
  actions :all, except: %i[new create destroy]
  config.batch_actions = false

  permit_params :admin_state, :access_policy_mode, :maintenance_reason, user_ids: []

  filter :module_key
  filter :name
  filter :admin_state, as: :select, collection: RegisteredModule::ADMIN_STATES
  filter :runtime_status, as: :select, collection: RegisteredModule::RUNTIME_STATUSES
  filter :access_policy_mode, as: :select, collection: RegisteredModule::ACCESS_POLICY_MODES

  member_action :enable, method: :post do
    if resource.ready_to_enable? || resource.runtime_status.in?(RegisteredModule::USER_AVAILABLE_RUNTIME_STATUSES)
      resource.update!(admin_state: "enabled")
      redirect_to resource_path(resource), notice: "Module enabled."
    else
      redirect_to resource_path(resource), alert: "Module is not healthy enough to enable."
    end
  end

  member_action :disable, method: :post do
    resource.update!(admin_state: "disabled")
    redirect_to resource_path(resource), notice: "Module disabled."
  end

  member_action :maintenance, method: :post do
    resource.update!(admin_state: "maintenance", maintenance_reason: params[:maintenance_reason])
    redirect_to resource_path(resource), notice: "Module placed in maintenance mode."
  end

  member_action :clear_maintenance, method: :post do
    resource.update!(admin_state: "registered", maintenance_reason: nil)
    redirect_to resource_path(resource), notice: "Maintenance mode cleared."
  end

  member_action :refresh_manifest, method: :post do
    result = refresh_reference_manifest(resource)
    redirect_to resource_path(resource), **refresh_redirect_options(result, "Manifest refreshed.")
  end

  member_action :refresh_status, method: :post do
    result = refresh_reference_status(resource)
    redirect_to resource_path(resource), **refresh_redirect_options(result, "Status refreshed.")
  end

  action_item :enable, only: :show do
    link_to "Enable", enable_admin_registered_module_path(resource), method: :post
  end

  action_item :disable, only: :show do
    link_to "Disable", disable_admin_registered_module_path(resource), method: :post
  end

  action_item :maintenance, only: :show do
    link_to "Maintenance", maintenance_admin_registered_module_path(resource), method: :post
  end

  action_item :clear_maintenance, only: :show do
    link_to "Clear maintenance", clear_maintenance_admin_registered_module_path(resource), method: :post
  end

  action_item :refresh_manifest, only: :show do
    link_to "Refresh manifest", refresh_manifest_admin_registered_module_path(resource), method: :post
  end

  action_item :refresh_status, only: :show do
    link_to "Refresh status", refresh_status_admin_registered_module_path(resource), method: :post
  end

  index do
    column :module_key
    column :name
    column :version
    column "Availability" do |registered_module|
      span registered_module.availability_label, title: registered_module.availability_blocker
    end
    column :admin_state
    column :runtime_status
    column :access_policy_mode
    column :last_manifest_refreshed_at
    column :last_status_refreshed_at
    actions defaults: true
  end

  show do
    attributes_table do
      row :module_key
      row :name
      row :version
      row :adapter_url
      row :adapter_protocol_version
      row :admin_state
      row :runtime_status
      row :access_policy_mode
      row("Availability") { |registered_module| registered_module.availability_label }
      row("Availability details") { |registered_module| registered_module.availability_blocker }
      row :maintenance_reason
      row :last_manifest_refreshed_at
      row :last_status_refreshed_at
    end

    panel "Manifest diagnostics" do
      pre JSON.pretty_generate(resource.manifest_snapshot)
    end

    panel "Status diagnostics" do
      pre JSON.pretty_generate(resource.status_snapshot)
    end
  end

  form do |f|
    f.inputs do
      f.input :admin_state,
        as: :select,
        collection: RegisteredModule::ADMIN_STATES,
        hint: "Controls whether the module is registered, enabled, disabled, or in maintenance."
      f.input :access_policy_mode,
        as: :select,
        collection: RegisteredModule::ACCESS_POLICY_MODES,
        hint: "Controls which signed-in users may access the module."
      f.input :maintenance_reason,
        hint: "Explain why the module is in maintenance mode."
      f.input :allowed_users,
        as: :check_boxes,
        collection: User.active.order(:email),
        hint: "Select the users allowed to access this module when policy requires it."
    end
    f.actions
  end

  controller do
    helper_method :refresh_reference_manifest, :refresh_reference_status, :refresh_redirect_options

    private

    def refresh_reference_manifest(registered_module)
      return failure_result("Only the local reference Notes adapter can be refreshed here.") unless reference_notes_runtime?(registered_module)

      Modules::RefreshManifest.call(
        registered_module: registered_module,
        adapter_secret: Modules::RegisterReferenceNotes::ADAPTER_SECRET
      )
    end

    def refresh_reference_status(registered_module)
      return failure_result("Only the local reference Notes adapter can be refreshed here.") unless reference_notes_runtime?(registered_module)

      Modules::RefreshStatus.call(
        registered_module: registered_module,
        adapter_secret: Modules::RegisterReferenceNotes::ADAPTER_SECRET
      )
    end

    def reference_notes_runtime?(registered_module)
      registered_module.module_key == "notes" && registered_module.adapter_url == Modules::RegisterReferenceNotes::ADAPTER_URL
    end

    def failure_result(message)
      Modules::RegisterAdapter::Result.new(success?: false, registered_module: resource, errors: [ message ])
    end

    def refresh_redirect_options(result, success_message)
      return { notice: success_message } if result.success?

      { alert: "Refresh failed: #{result.errors.join('; ')}" }
    end
  end
end
