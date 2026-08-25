class HardenTelegramOperations < ActiveRecord::Migration[8.1]
  def up
    add_column :telegram_accounts, :connection_state, :string, null: false, default: "disconnected"
    add_column :telegram_accounts, :auth_challenge, :jsonb, null: false, default: {}

    add_index :folders, %i[id telegram_account_id], unique: true, name: "index_folders_on_id_and_account"
    add_index :snapshots, %i[id telegram_account_id], unique: true, name: "index_snapshots_on_id_and_account"
    add_index :operations, %i[id telegram_account_id], unique: true, name: "index_operations_on_id_and_account"

    remove_foreign_key :assignments, :folders
    remove_foreign_key :rules, :folders
    remove_foreign_key :operations, :snapshots, column: :before_snapshot_id
    remove_foreign_key :operation_steps, :operations

    add_foreign_key :assignments, :folders, column: %i[folder_id telegram_account_id], primary_key: %i[id telegram_account_id]
    add_foreign_key :rules, :folders, column: %i[target_folder_id telegram_account_id], primary_key: %i[id telegram_account_id]
    add_foreign_key :operations, :snapshots, column: %i[before_snapshot_id telegram_account_id], primary_key: %i[id telegram_account_id]
    add_foreign_key :operation_steps, :operations, column: %i[operation_id telegram_account_id], primary_key: %i[id telegram_account_id]
  end

  def down
    remove_foreign_key :operation_steps, column: %i[operation_id telegram_account_id]
    remove_foreign_key :operations, column: %i[before_snapshot_id telegram_account_id]
    remove_foreign_key :rules, column: %i[target_folder_id telegram_account_id]
    remove_foreign_key :assignments, column: %i[folder_id telegram_account_id]

    add_foreign_key :operation_steps, :operations
    add_foreign_key :operations, :snapshots, column: :before_snapshot_id
    add_foreign_key :rules, :folders, column: :target_folder_id
    add_foreign_key :assignments, :folders

    remove_index :operations, name: "index_operations_on_id_and_account"
    remove_index :snapshots, name: "index_snapshots_on_id_and_account"
    remove_index :folders, name: "index_folders_on_id_and_account"
    remove_column :telegram_accounts, :auth_challenge
    remove_column :telegram_accounts, :connection_state
  end
end
