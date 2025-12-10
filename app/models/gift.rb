class Gift < ApplicationRecord
  # --- Associations ---
  belongs_to :lucky_draw_session
  has_many :gift_winners, dependent: :destroy

  # --- Validations ---
  validates :lucky_draw_session_id, presence: true
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true }
  validates :winner_counts, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # --- Scopes ---
  scope :ordered, -> { order(:order) }

  # --- Class Methods ---
  def self.next_order(lucky_draw_session_id)
    max_order = where(lucky_draw_session_id: lucky_draw_session_id).maximum(:order)
    max_order ? max_order + 1 : 1
  end

  # --- Instance Methods ---
  # Check if this gift needs more winners
  def needs_more_winners?
    gift_winners.count < winner_counts
  end

  # Get the number of winners still needed
  def winners_needed
    [winner_counts - gift_winners.count, 0].max
  end
end