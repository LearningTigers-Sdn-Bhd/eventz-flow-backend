class ExhibitorKit < ApplicationRecord
  belongs_to :event_vendor, class_name: 'Exhibitor', inverse_of: :exhibitor_kit
  has_many :exhibitor_team_members, dependent: :destroy
  accepts_nested_attributes_for :exhibitor_team_members, allow_destroy: true

  enum :booth_type, { shell_scheme: 0, raw_space: 1 }

  validates :booth_number, presence: true
  validates :booth_type, presence: true
  validates :name_on_fascia, presence: true, length: { maximum: 25 }
  validates :company_name, presence: true
  validates :company_address, presence: true
  validates :pic_full_name, presence: true
  validates :pic_contact_number, presence: true
  validates :pic_email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
