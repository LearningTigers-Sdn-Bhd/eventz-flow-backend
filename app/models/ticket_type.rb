class TicketType < ApplicationRecord
  # 🔑 This line is the fix: It creates the 'event' association and the 'event=' method.
  # Made optional to support global ticket types (templates)
  belongs_to :event, optional: true
  has_many :tickets # Assuming a future Ticket model

  # Enums for Status
  enum :status, { draft: 0, published: 1, archived: 2 }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_per_order, presence: true, numericality: { greater_than_or_equal_to: 1 }

  # Scopes
  scope :global, -> { where(event_id: nil) }
  scope :event_specific, -> { where.not(event_id: nil) }
  scope :publicly_available, -> { published.where(hidden: false) }
  scope :on_sale, -> { 
    where('sale_starts_at IS NULL OR sale_starts_at <= ?', Time.current)
    .where('sale_ends_at IS NULL OR sale_ends_at >= ?', Time.current)
  }

  # Helper method to check if the ticket type is currently available for purchase
  def available?
    published? && !hidden? && on_sale?
  end

  private

  def on_sale?
    (sale_starts_at.nil? || sale_starts_at <= Time.current) &&
    (sale_ends_at.nil? || sale_ends_at >= Time.current)
  end
end