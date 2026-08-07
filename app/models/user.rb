class User < ApplicationRecord
  # --- Authentication ---
  has_secure_password

  # --- Global Roles ---
  # Rails best practice is to use the provided methods (org_owner?, organizer?, etc.)
  # The enum values should remain integers for database consistency.
  enum :role, { org_owner: 0, organizer: 1, member: 2, vendor: 3, exhibitor: 4, exhibition_contractor: 5 }, scopes: false

  # --- Status ---
  enum :status, { active: 1, inactive: 0 }

  # --- Callbacks ---
  after_initialize :set_default_role, if: :new_record?
  after_initialize :set_default_status, if: :new_record?
  before_create :generate_jti
  after_create :create_associated_profile

  # --- Validations ---
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
  validates :full_name, presence: true
  validates :status, presence: true

  # --- Scopes ---
  scope :members, -> { where(role: :member) }
  scope :org_owners, -> { where(role: :org_owner) }
  scope :organizers, -> { where(role: :organizer) }
  scope :org_staff, -> { where(role: [:org_owner, :organizer]) }
  scope :created_by_user, ->(user) { where(created_by_id: user.id) }

  # --- Associations ---

  # Session Management
  has_many :user_sessions, dependent: :destroy
  has_many :active_sessions, -> { active }, class_name: 'UserSession'

  # 0. USER CREATION TRACKING
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :created_users, class_name: 'User', foreign_key: 'created_by_id', dependent: :nullify

  # 1. EVENT STAFFING (Unified Event Assignment Model)
  has_many :event_assignments, dependent: :destroy
  has_many :assigned_events, through: :event_assignments, source: :event

  has_many :business_host_assignments, dependent: :destroy # Added association

  # Event vendor assignments (for exhibitors/merchants)
  has_many :event_vendor_assignments, class_name: 'EventVendor', foreign_key: 'vendor_id', dependent: :destroy
  has_many :vendor_events, through: :event_vendor_assignments, source: :event

  # Vendor profile (for vendors only - one profile per vendor)
  has_one :vendor_profile, foreign_key: 'vendor_id', dependent: :destroy
  accepts_nested_attributes_for :vendor_profile

  # Exhibition Contractor profile (for exhibition_contractors only - one profile per contractor)
  has_one :exhibition_contractor_profile, foreign_key: 'user_id', dependent: :destroy
  has_many :events_as_contractor, through: :exhibition_contractor_profile, source: :events

  # 2. GROUP MEMBERSHIPS
  has_many :group_memberships, class_name: 'GroupMember', dependent: :destroy
  has_many :groups, through: :group_memberships

  # 3. EVENT LOCATION ASSIGNMENTS
  has_many :event_location_members, foreign_key: :member_id, dependent: :destroy
  has_many :assigned_locations, through: :event_location_members, source: :event_location

  # Add the required scoped association for the controller (Failures 8, 9 from previous run)
  has_many :assigned_event_admins, -> { where(role: EventAssignment.roles[:event_admin]) },
           class_name: 'EventAssignment',
           dependent: :destroy

  # 4. PARTICIPATION
  has_many :tickets, dependent: :destroy
  has_many :rentable_items, dependent: :destroy
  has_many :printing_services, dependent: :destroy
  has_many :exhibitor_kit_admin_notes, dependent: :destroy
  has_one :payment_detail, dependent: :destroy


  # 5. VOUCHER REDEMPTIONS
  has_many :voucher_usages, as: :redeemer, dependent: :destroy
  has_many :voucher_redemption_logs, as: :redeemer, dependent: :destroy

  # 6. SECURITY
  has_many :api_keys, dependent: :destroy
  has_many :email_verifications, dependent: :destroy

  # 7. RESOURCES
  has_one :resource_write_permission, dependent: :destroy
  has_many :resources, foreign_key: 'user_id', dependent: :destroy

  # 8. PRIZE ROULETTE
  has_many :roulette_sessions, dependent: :destroy
  has_many :roulette_assigns, dependent: :destroy

  # --- Resource-Specific Role Helper Methods ---

  def can_write_resources?
    resource_write_permission.present?
  end

  def is_official_writer?
    resource_write_permission&.is_official?
  end

  # --- Global Role Helper Methods (FIXED LOGIC) ---

  # Ensures Org Owner is included as a Organizer
  def is_organizer?
    organizer? || org_owner?
  end

  # Check if a user is an Org Owner or Organizer
  def is_org_owner_or_organizer?
    is_organizer?
  end

  # Pure check for Org Owner role
  def is_org_owner?
    org_owner?
  end

  # Pure check for Member role (exclusive of Organizer/Owner)
  def is_member?
    member?
  end

  # --- Event-Specific Role Helper Methods ---

  def is_event_admin?(event)
    return false unless event.present?
    # Use enum value from EventAssignment class directly for robustness
    event_assignments.exists?(event_id: event.id, role: EventAssignment.roles[:event_admin])
  end

  def is_event_team_member?(event)
    return false unless event.present?
    event_assignments.exists?(event_id: event.id, role: EventAssignment.roles[:event_team_member])
  end

  def is_business_matching_admin?(event)
    return false unless event.present?
    event_assignments.exists?(event_id: event.id, role: EventAssignment.roles[:business_matching_admin])
  end

  # Event ids where this user holds the business_matching_admin role.
  def business_matching_admin_event_ids
    event_assignments.where(role: EventAssignment.roles[:business_matching_admin]).pluck(:event_id)
  end

  # True if this user's ONLY standing on the platform is business_matching_admin
  # for one or more events — no org-level staff role, no full event-admin/team
  # standing anywhere. Used to hide the generic app nav/dashboard and send them
  # straight into Business Matching instead.
  def only_business_matching_admin?
    return false if is_org_owner_or_organizer?
    return false if business_matching_admin_event_ids.empty?

    !event_assignments.where(
      role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]]
    ).exists?
  end

  # Standard user payload returned by auth/profile endpoints.
  def public_json
    slice(:id, :full_name, :email, :role, :phone).merge(
      email_verified: email_verified?,
      is_pure_business_matching_admin: only_business_matching_admin?,
      business_matching_admin_event_ids: business_matching_admin_event_ids.map(&:to_s)
    )
  end

  def is_event_staff?(event)
    return false unless event.present?
    event_assignments.where(event_id: event.id)
                     .where(role: [EventAssignment.roles[:event_admin], EventAssignment.roles[:event_team_member]])
                     .exists?
  end

  def is_event_vendor?(event)
    return false unless event.present?

    event_vendor_assignments.exists?(event_id: event.id)
  end

  def is_business_host?(event)
    return false unless event.present?
    exhibitor? ||
      event_assignments.exists?(event_id: event.id, role: EventAssignment.roles[:business_host]) ||
      business_host_assignments.exists?(event_id: event.id)
  end

  # --- Group Role Helper Methods ---

  def is_group_manager?(group)
    return false unless group.present?

    group.group_members.where(user_id: id, has_manager_access: true).exists?
  end

  # --- Email Verification ---

  def email_verified?
    email_verified_at.present?
  end

  # --- JTI Management ---

  # Regenerate JTI for token revocation
  def refresh_jti!
    update!(jti: SecureRandom.uuid)
  end

  def is_vendor?
    vendor?
  end

  def is_exhibition_contractor?
    exhibition_contractor?
  end

  def is_staff?
    ['org_owner', 'organizer', 'member'].include?(role)
  end

  # Convenience methods for policies
  def admin?
    org_owner?
  end

  def organizer?
    self.role == 'organizer' || self.role == 'org_owner'
  end

  def exhibitor?
    self.role == 'exhibitor'
  end

  def exhibition_contractor?
    self.role == 'exhibition_contractor'
  end

  def admin_or_organizer?
    admin? || organizer?
  end

  def exhibition_contractor_for?(event)
    return false unless event.present?

    exhibition_contractor_profile.present? &&
      exhibition_contractor_profile.event_exhibition_contractors.exists?(event_id: event.id)
  end

  attr_accessor :skip_profile_creation

  private

  # Use the Rails enum helper methods (org_owner?, organizer?, etc.) instead of string comparisons ('organizer')
  # when the methods are defined on the User class itself.

  def set_default_role
    # Use the symbol/key provided in the enum definition
    self.role ||= :member
  end

  def set_default_status
    self.status ||= :active
  end

  def generate_jti
    self.jti = SecureRandom.uuid
  end

  def create_associated_profile
    return if skip_profile_creation

    if vendor?
      VendorProfile.create(vendor: self) unless vendor_profile.present?
    elsif exhibition_contractor?
      ExhibitionContractorProfile.create(user: self) unless exhibition_contractor_profile.present?
    end
  end
end
