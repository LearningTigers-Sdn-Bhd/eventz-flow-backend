class ExhibitorKit < ApplicationRecord
  belongs_to :event_vendor, class_name: 'Exhibitor', inverse_of: :exhibitor_kit
  has_many :exhibitor_team_members, dependent: :destroy
  accepts_nested_attributes_for :exhibitor_team_members, allow_destroy: true

  delegate :event, to: :event_vendor

  enum :booth_type, { shell_scheme: 0, raw_space: 1 }
  enum :payment_status, { unpaid: 0, paid: 1, waived: 2, sponsored: 3 }

  # Booth/company info - optional but validated if provided
  validates :booth_number, presence: true, allow_blank: true
  validates :name_on_fascia, length: { maximum: 25 }, allow_blank: true
  validates :company_name, presence: true, allow_blank: true
  validates :company_address, presence: true, allow_blank: true
  
  # PIC info - required
  validates :pic_full_name, presence: true
  validates :pic_contact_number, presence: true
  validates :pic_email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :amount_paid, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
