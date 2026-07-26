class AddPlatformFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :display_name, :string, null: false, default: ""
    add_column :users, :role, :string, null: false, default: "user"
    add_column :users, :active, :boolean, null: false, default: true

    add_index :users, :role
    add_index :users, :active
  end
end
