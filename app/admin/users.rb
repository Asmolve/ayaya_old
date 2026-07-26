ActiveAdmin.register User do
  actions :all, except: :destroy
  config.batch_actions = false

  permit_params :email, :display_name, :role, :active, :password, :password_confirmation

  filter :email
  filter :display_name
  filter :role, as: :select, collection: User::ROLES
  filter :active

  index do
    selectable_column
    id_column
    column :email
    column :display_name
    column :role
    column :active
    column :created_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :display_name
      f.input :role, as: :select, collection: User::ROLES
      f.input :active
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end
end
