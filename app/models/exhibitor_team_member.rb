class ExhibitorTeamMember < ApplicationRecord
  belongs_to :exhibitor_kit

  validates :full_name, presence: true
end
