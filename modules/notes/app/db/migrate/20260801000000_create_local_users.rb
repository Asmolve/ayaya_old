class CreateLocalUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :local_users do |t|
      t.string :core_user_id, null: false
      t.string :email
      t.string :display_name
      t.string :global_role
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :local_users, :core_user_id, unique: true
  end
end
