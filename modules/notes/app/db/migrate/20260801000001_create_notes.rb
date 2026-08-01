class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :local_user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body

      t.timestamps
    end
  end
end
