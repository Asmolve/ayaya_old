class AddAvatarUrlToDialogs < ActiveRecord::Migration[8.1]
  def change
    add_column :dialogs, :avatar_url, :string
  end
end
