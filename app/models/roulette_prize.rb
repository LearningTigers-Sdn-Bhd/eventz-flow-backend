class RoulettePrize < ApplicationRecord
  # --- Associations ---
  belongs_to :roulette_session
  has_many :roulette_winners, dependent: :destroy

  # --- Active Storage ---
  has_one_attached :image, dependent: :purge_later

  # --- Validations ---
  validates :roulette_session_id, presence: true
  validates :name, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # --- Scopes ---
  scope :ordered, -> { order(created_at: :asc) }

  # --- Helper Methods ---
  def remaining_quantity
    quantity - roulette_winners.count
  end

  def has_winner?
    roulette_winners.exists?
  end
end
