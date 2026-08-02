ActiveAdmin.register RegisteredModule do
  actions :all, except: %i[new create destroy]
  config.batch_actions = false

  permit_params :admin_state, :access_policy_mode, :maintenance_reason, user_ids: []

  filter :module_key
  filter :name
  filter :admin_state, as: :select, collection: RegisteredModule::ADMIN_STATES
  filter :runtime_status, as: :select, collection: RegisteredModule::RUNTIME_STATUSES
  filter :access_policy_mode, as: :select, collection: RegisteredModule::ACCESS_POLICY_MODES

  index do
    column :module_key
    column :name
    column :version
    column "Availability" do |registered_module|
      registered_module.availability_label
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
end
