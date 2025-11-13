class Group < ApplicationRecord
  # --- Associations ---
  has_many :group_members, dependent: :destroy
  has_many :users, through: :group_members
  has_one :group_affiliate, dependent: :destroy
  has_one :vendor, through: :group_affiliate, class_name: 'User'
  has_many :vendor_profiles, dependent: :destroy

  # --- Validations ---
  validates :name, presence: true

  # --- Scopes ---
  scope :with_vendor, -> { joins(:group_affiliate) }
  scope :managed_by, ->(user) { joins(:group_members).where(group_members: { user_id: user.id, has_manager_access: true }) }
  scope :visible_to, ->(user) {
    if user&.org_owner?
      all
    elsif user&.vendor?
      joins(:group_affiliate).where(group_affiliates: { vendor_id: user.id })
    else
      joins(:group_members).where(group_members: { user_id: user.id }).distinct
    end
  }
end
