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
  validate :participant_not_already_winner

  private

  def exactly_one_participant
    if ticket_id.blank? && visitor_id.blank?
      errors.add(:base, 'Either ticket_id or visitor_id must be present')
    elsif ticket_id.present? && visitor_id.present?
      errors.add(:base, 'Cannot have both ticket_id and visitor_id')
    end
  end

  def participant_not_already_winner
    return unless roulette_session_id.present?

    # Only prevent duplicates if is_multiple is false
    # When is_multiple is true, same participant can win multiple times
    return if roulette_session&.is_multiple == true

    existing_winner = if ticket_id.present?
      RouletteWinner.where(roulette_session_id: roulette_session_id, ticket_id: ticket_id)
                    .where.not(id: id)
                    .exists?
    elsif visitor_id.present?
      RouletteWinner.where(roulette_session_id: roulette_session_id, visitor_id: visitor_id)
                    .where.not(id: id)
                    .exists?
    end

    if existing_winner
      participant_name = ticket&.attendee_name || visitor&.full_name || 'This participant'
      errors.add(:base, "#{participant_name} has already won a prize in this session")
    end
  end
end
