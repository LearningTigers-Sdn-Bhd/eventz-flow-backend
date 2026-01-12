class Sponsor < ApplicationRecord
  # --- Associations ---
  belongs_to :group
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :event_sponsorships, dependent: :destroy
  has_many :events, through: :event_sponsorships

  # --- Validations ---
  validates :name, presence: true, uniqueness: { scope: :group_id, case_sensitive: false }
  
  # --- Soft Delete ---
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }
  scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  # --- Analytics ---
  def total_sponsorship_count
    event_sponsorships.count
  end

  def total_pledged_amount
    event_sponsorships.sum(:total_sponsor_amount)
  end

  def total_received_amount
    event_sponsorships.sum(:received_total)
  end
end
