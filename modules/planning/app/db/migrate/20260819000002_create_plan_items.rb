class CreatePlanItems < ActiveRecord::Migration[8.1]
  def change
    create_table :plan_items do |t|
      t.references :plan, null: false, foreign_key: true
      t.string :title, null: false
      t.text :notes
      t.string :priority, null: false, default: "next"
      t.integer :position, null: false, default: 0
      t.boolean :completed, null: false, default: false

      t.timestamps
    end

    add_index :plan_items, %i[plan_id priority position]
  end
end
