ActiveAdmin.register RegisteredModule do
  permit_params :admin_state, :access_policy_mode, :maintenance_reason, user_ids: []

  filter :module_key
  filter :name
  filter :admin_state, as: :select, collection: RegisteredModule::ADMIN_STATES
  filter :runtime_status, as: :select, collection: RegisteredModule::RUNTIME_STATUSES
  filter :access_policy_mode, as: :select, collection: RegisteredModule::ACCESS_POLICY_MODES

  index do
    selectable_column
    id_column
    column :module_key
    column :name
    column :version
    column :admin_state
    column :runtime_status
    column :access_policy_mode
    column :last_manifest_refreshed_at
    column :last_status_refreshed_at
    actions
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
      row :manifest_snapshot do |record|
        pre JSON.pretty_generate(record.manifest_snapshot)
      end
      row :status_snapshot do |record|
        pre JSON.pretty_generate(record.status_snapshot)
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :admin_state, as: :select, collection: RegisteredModule::ADMIN_STATES
      f.input :access_policy_mode, as: :select, collection: RegisteredModule::ACCESS_POLICY_MODES
      f.input :maintenance_reason
      f.input :allowed_users, as: :check_boxes, collection: User.active.order(:email)
    end
    f.actions
  end
end
