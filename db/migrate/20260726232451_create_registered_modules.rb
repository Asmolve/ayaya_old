class CreateRegisteredModules < ActiveRecord::Migration[8.1]
  def change
    create_table :registered_modules do |t|
      t.string :module_key, null: false
      t.string :name, null: false
      t.string :version, null: false
      t.string :adapter_url, null: false
      t.string :adapter_secret_digest, null: false
      t.string :adapter_protocol_version, null: false
      t.string :admin_state, null: false, default: "registered"
      t.string :runtime_status, null: false, default: "unknown"
      t.string :access_policy_mode, null: false, default: "manual"
      t.jsonb :manifest_snapshot, null: false, default: {}
      t.jsonb :status_snapshot, null: false, default: {}
      t.text :maintenance_reason
      t.datetime :last_manifest_refreshed_at
      t.datetime :last_status_refreshed_at

      t.timestamps
    end

    add_index :registered_modules, :module_key, unique: true
    add_index :registered_modules, :admin_state
    add_index :registered_modules, :runtime_status
    add_index :registered_modules, :access_policy_mode
  end
end
