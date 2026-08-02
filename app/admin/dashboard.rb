# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    registered_modules = RegisteredModule.order(:module_key)

    panel "Module Operations" do
      if registered_modules.empty?
        div class: "blank_slate_container" do
          span class: "blank_slate" do
            span "No modules registered"
            small do
              link_to "Register the local Notes adapter", admin_registered_modules_path
            end
          end
        end
      else
        div class: "dashboard-summary" do
          columns do
            column do
              para "Registered modules"
              para registered_modules.count
            end

            column do
              para "Enabled modules"
              para registered_modules.where(admin_state: "enabled").count
            end

            column do
              para "Usable modules"
              para registered_modules.count(&:user_available?)
            end

            column do
              para "Modules needing attention"
              para registered_modules.count { |registered_module| registered_module.availability_label == "needs attention" }
            end
          end
        end

        table_for registered_modules do
          column :module_key do |registered_module|
            link_to registered_module.module_key, admin_registered_module_path(registered_module)
          end
          column :name
          column :admin_state do |registered_module|
            status_tag registered_module.admin_state
          end
          column :runtime_status do |registered_module|
            status_tag registered_module.runtime_status
          end
          column :access_policy_mode
          column "Availability" do |registered_module|
            div title: registered_module.availability_blocker do
              status_tag registered_module.availability_label, label: registered_module.availability_label
            end
          end
        end
      end

      para do
        link_to "View all registered modules", admin_registered_modules_path
      end
    end
  end
end
