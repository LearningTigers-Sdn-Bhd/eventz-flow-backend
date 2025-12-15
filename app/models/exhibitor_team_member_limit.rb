class ExhibitorTeamMemberLimit < ApplicationRecord
  belongs_to :event

  # Validations
  validates :event_id, uniqueness: true
  validates :team_member_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :extra_team_member_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Check if a limit is set (nil means unlimited)
  def has_limit?
    team_member_limit.present? && team_member_limit > 0
  end

  # Check if charging extra fee is enabled
  def charges_extra_fee?
    extra_team_member_fee.present? && extra_team_member_fee > 0
  end
end
