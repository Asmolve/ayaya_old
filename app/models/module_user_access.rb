class ModuleUserAccess < ApplicationRecord
  belongs_to :registered_module
  belongs_to :user

  validates :user_id, uniqueness: { scope: :registered_module_id }
end
