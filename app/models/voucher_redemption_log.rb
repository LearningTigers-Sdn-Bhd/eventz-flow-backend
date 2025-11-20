# Audits every successful voucher redemption transaction.
class VoucherRedemptionLog < ApplicationRecord
  # --- Enums ---
  enum :redeemer_type, { user_redeemer: 0, visitor_redeemer: 1 }
  enum :redemption_status, { completed: 0, cancelled: 1 }

  # --- Associations ---
  belongs_to :voucher
  belongs_to :redeemer, polymorphic: true, foreign_type: 'polymorphic_redeemer_type'
  belongs_to :redeemer_staff, class_name: 'User', foreign_key: 'redeemer_staff_id', optional: true

  # --- Validations ---
  validates :voucher, presence: true
  validates :redeemer, presence: true
  validates :redemption_timestamp, presence: true
  validates :redemption_status, presence: true
  validates :transaction_gross_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_applied_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :transaction_net_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # --- Scopes ---
  scope :for_event, ->(event) { joins(:voucher).where(vouchers: { event: event }) }
  scope :total_discount_value, -> { sum(:discount_applied_value) }
  scope :total_sales, -> { sum(:transaction_net_amount) }
  scope :daily_redemption_trend, -> { group_by_day(:redemption_timestamp).count }
  scope :top_scanned_vouchers, -> { joins(:voucher).group('vouchers.title').order('count_all DESC').limit(5).count }
  scope :latest_redemption_transactions, -> { order(redemption_timestamp: :desc).limit(10) }
end