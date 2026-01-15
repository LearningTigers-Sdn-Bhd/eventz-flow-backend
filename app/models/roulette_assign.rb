class RouletteAssign < ApplicationRecord
  # --- Associations ---
  belongs_to :roulette_session
  belongs_to :user

  # --- Validations ---
  validates :roulette_session_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :roulette_session_id, message: 'is already assigned to this session' }
end
