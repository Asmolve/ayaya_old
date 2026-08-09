class AddDiaryFieldsToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :entry_type, :string, null: false, default: "regular"
    add_column :notes, :start_date, :date
    add_column :notes, :end_date, :date
    add_index :notes, %i[local_user_id start_date end_date], unique: true,
              where: "entry_type = 'diary'", name: "index_notes_on_user_and_diary_range"
  end
end
