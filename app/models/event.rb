class Event < ApplicationRecord
  has_many :event_admins, dependent: :destroy
  has_many :admins, through: :event_admins, source: :user

  has_many :event_team_members, dependent: :destroy
  has_many :team_members, through: :event_team_members, source: :user

  has_many :ticket_types, dependent: :destroy
  has_many :tickets, dependent: :destroy

  validates :title, presence: true, length: { maximum: 100 }
  validates :status, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  validate :end_date_must_be_after_start_date

  enum :status, { draft: 0, published: 1, cancelled: 2 }
  enum :payment_status, { unpaid: 0, paid: 1, waived: 2 }

  private

  def end_date_must_be_after_start_date
    if start_date.present? && end_date.present? && end_date < start_date
      errors.add(:end_date, 'must be after the start date')
    end
  end
end
