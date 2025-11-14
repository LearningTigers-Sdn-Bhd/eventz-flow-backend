class Group < ApplicationRecord
  # --- Associations ---
  has_many :group_members, dependent: :destroy
  has_many :users, through: :group_members
  has_many :group_affiliates, dependent: :destroy
  has_many :vendors, through: :group_affiliates, source: :vendor, class_name: 'User'
  has_many :vendor_profiles, dependent: :destroy

  # --- Validations ---
  validates :name, presence: true

  # --- Scopes ---
  scope :with_vendor, -> { joins(:group_affiliates).distinct }
  scope :managed_by, ->(user) { joins(:group_members).where(group_members: { user_id: user.id, has_manager_access: true }) }
  scope :visible_to, ->(user) {
    if user&.org_owner?
      all
    elsif user&.vendor?
      joins(:group_affiliates).where(group_affiliates: { vendor_id: user.id }).distinct
    else
      joins(:group_members).where(group_members: { user_id: user.id }).distinct
    end
  }
end
