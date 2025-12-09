class ExhibitorKitAdminNote < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :user

  validates :note, presence: true
end
