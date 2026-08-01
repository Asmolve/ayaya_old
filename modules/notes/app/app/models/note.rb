class Note < ApplicationRecord
  belongs_to :local_user

  validates :title, presence: true
end
