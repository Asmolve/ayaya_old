class AddFolderProposalsAndOwnershipState < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?(:folder_proposals)
      create_table :folder_proposals do |t|
        t.references :telegram_account, null: false, foreign_key: true
        t.string :proposal_id, null: false
        t.string :category, null: false
        t.string :title, null: false
        t.string :status, null: false, default: "proposed"
        t.jsonb :explanation, null: false, default: {}
        t.datetime :accepted_at
        t.timestamps
      end
    end
    add_index :folder_proposals, %i[telegram_account_id proposal_id], unique: true unless index_exists?(:folder_proposals, %i[telegram_account_id proposal_id], unique: true)
    add_index :folder_proposals, %i[telegram_account_id category], unique: true unless index_exists?(:folder_proposals, %i[telegram_account_id category], unique: true)

    add_column :folders, :ownership_state, :string, null: false, default: "foreign" unless column_exists?(:folders, :ownership_state)
    execute <<~SQL.squish
      UPDATE folders
      SET ownership_state = 'confirmed'
      FROM telegram_accounts
      WHERE folders.telegram_account_id = telegram_accounts.id
        AND folders.managed_by_app = TRUE
        AND folders.ownership_record ->> 'account_id' = telegram_accounts.telegram_account_id
        AND folders.ownership_record ->> 'telegram_folder_id' = folders.telegram_folder_id::text
        AND NULLIF(folders.ownership_record ->> 'fingerprint', '') IS NOT NULL
        AND folders.remote_fingerprint = folders.ownership_record ->> 'fingerprint'
    SQL
    add_index :folders, %i[telegram_account_id ownership_state] unless index_exists?(:folders, %i[telegram_account_id ownership_state])
  end

  def down
    remove_index :folders, column: %i[telegram_account_id ownership_state] if index_exists?(:folders, %i[telegram_account_id ownership_state])
    remove_column :folders, :ownership_state if column_exists?(:folders, :ownership_state)
    remove_index :folder_proposals, column: %i[telegram_account_id category] if index_exists?(:folder_proposals, %i[telegram_account_id category])
    remove_index :folder_proposals, column: %i[telegram_account_id proposal_id] if index_exists?(:folder_proposals, %i[telegram_account_id proposal_id])
    drop_table :folder_proposals if table_exists?(:folder_proposals)
  end
end
