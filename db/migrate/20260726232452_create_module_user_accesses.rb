class CreateModuleUserAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :module_user_accesses do |t|
      t.references :registered_module, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :module_user_accesses, [:registered_module_id, :user_id], unique: true, name: "index_module_access_on_module_and_user"
  end
end
