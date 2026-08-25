class CreateTelegramDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :module_users do |t|
      t.string :core_user_id, null: false
      t.string :email
      t.string :display_name
      t.string :global_role
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :module_users, :core_user_id, unique: true

    create_table :telegram_accounts do |t|
      t.references :module_user, null: false, foreign_key: true
      t.string :telegram_account_id, null: false
      t.string :display_name
      t.jsonb :encrypted_session
      t.jsonb :encrypted_api_credentials
      t.boolean :read_only, null: false, default: true
      t.datetime :last_seen_at
      t.datetime :disconnected_at
      t.timestamps
    end
    add_index :telegram_accounts, :module_user_id, unique: true, name: "index_telegram_accounts_one_per_module_user"
    add_index :telegram_accounts, %i[module_user_id telegram_account_id], unique: true

    create_table :dialogs do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.string :peer_kind, null: false
      t.string :peer_id, null: false
      t.jsonb :input_peer_ref, null: false, default: {}
      t.string :access_hash
      t.string :title, null: false
      t.string :username
      t.string :metadata_hash, null: false
      t.datetime :last_seen_at
      t.datetime :stale_at
      t.timestamps
    end
    add_index :dialogs, %i[telegram_account_id peer_kind peer_id], unique: true

    create_table :folders do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.string :app_folder_id
      t.integer :telegram_folder_id, null: false
      t.string :title, null: false
      t.string :emoji
      t.boolean :managed_by_app, null: false, default: false
      t.jsonb :ownership_record, null: false, default: {}
      t.string :mode, null: false, default: "showcase"
      t.string :remote_fingerprint
      t.integer :local_revision, null: false, default: 0
      t.jsonb :remote_state, null: false, default: {}
      t.timestamps
    end
    add_index :folders, %i[telegram_account_id telegram_folder_id], unique: true

    create_table :assignments do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.references :folder, foreign_key: true
      t.string :peer_kind, null: false
      t.string :peer_id, null: false
      t.string :source, null: false
      t.decimal :confidence, precision: 5, scale: 4
      t.jsonb :explanation, null: false, default: {}
      t.boolean :locked, null: false, default: false
      t.timestamps
    end
    add_index :assignments, %i[telegram_account_id peer_kind peer_id], unique: true

    create_table :rules do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.string :rule_id, null: false
      t.integer :version, null: false, default: 1
      t.integer :priority, null: false
      t.jsonb :condition_json, null: false, default: {}
      t.references :target_folder, foreign_key: { to_table: :folders }
      t.boolean :enabled, null: false, default: true
      t.string :explanation
      t.timestamps
    end
    add_index :rules, %i[telegram_account_id rule_id version], unique: true

    create_table :snapshots do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.string :snapshot_id, null: false
      t.string :kind, null: false
      t.integer :canonical_version, null: false
      t.string :source_hash, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :retention_until
      t.timestamps
    end
    add_index :snapshots, %i[telegram_account_id snapshot_id], unique: true

    create_table :operations do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.string :operation_id, null: false
      t.string :status, null: false
      t.references :before_snapshot, foreign_key: { to_table: :snapshots }
      t.string :plan_fingerprint
      t.jsonb :plan, null: false, default: {}
      t.datetime :completed_at
      t.timestamps
    end
    add_index :operations, %i[telegram_account_id operation_id], unique: true

    create_table :operation_steps do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.references :operation, null: false, foreign_key: true
      t.string :step_id, null: false
      t.string :status, null: false, default: "planned"
      t.string :request_fingerprint, null: false
      t.string :precondition_fingerprint, null: false
      t.jsonb :expected_postcondition, null: false, default: {}
      t.string :result_fingerprint
      t.jsonb :error_json, null: false, default: {}
      t.timestamps
    end
    add_index :operation_steps, %i[telegram_account_id operation_id step_id], unique: true, name: "index_operation_steps_on_account_operation_step"

    create_table :account_leases do |t|
      t.references :telegram_account, null: false, foreign_key: true
      t.string :holder, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :account_leases, :telegram_account_id, unique: true, name: "index_account_leases_one_per_account"
  end
end
