class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.references :local_user, null: false, foreign_key: true
      t.string :title, null: false

      t.timestamps
    end
  end
end
