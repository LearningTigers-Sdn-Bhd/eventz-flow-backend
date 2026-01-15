class RouletteWinner < ApplicationRecord
  # --- Associations ---
  belongs_to :roulette_session
  belongs_to :roulette_prize
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true

  # --- Validations ---
  validates :roulette_session_id, presence: true
  validates :roulette_prize_id, presence: true
  validates :drawn_at, presence: true
  validate :exactly_one_participant

  private

  def exactly_one_participant
    if ticket_id.blank? && visitor_id.blank?
      errors.add(:base, 'Either ticket_id or visitor_id must be present')
    elsif ticket_id.present? && visitor_id.present?
      errors.add(:base, 'Cannot have both ticket_id and visitor_id')
    end
  end
end
