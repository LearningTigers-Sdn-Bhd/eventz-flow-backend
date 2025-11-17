class User < ApplicationRecord
  # --- Authentication ---
  has_secure_password

  # --- Global Roles ---
  # Rails best practice is to use the provided methods (org_owner?, organizer?, etc.)
  # The enum values should remain integers for database consistency.
  enum :role, { org_owner: 0, organizer: 1, member: 2, vendor: 3 }, scopes: false

  # --- Status ---
  enum :status, { active: 1, inactive: 0 }

  # --- Callbacks ---
  after_initialize :set_default_role, if: :new_record?
  after_initialize :set_default_status, if: :new_record?
  before_create :generate_jti

  # --- Validations ---
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
  validates :full_name, presence: true
  validates :status, presence: true

  # --- Associations ---

  # 0. USER CREATION TRACKING
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :created_users, class_name: 'User', foreign_key: 'created_by_id', dependent: :nullify

  # 1. EVENT STAFFING (Unified Event Assignment Model)
  has_many :event_assignments, dependent: :destroy
  has_many :assigned_events, through: :event_assignments, source: :event

  # Event vendor assignments (for exhibitors/merchants)
  has_many :event_vendor_assignments, class_name: 'EventVendor', foreign_key: 'vendor_id', dependent: :destroy
  has_many :vendor_events, through: :event_vendor_assignments, source: :event

  # 2. GROUP MEMBERSHIPS
  has_many :group_memberships, class_name: 'GroupMember', dependent: :destroy
  has_many :groups, through: :group_memberships

  # Add the required scoped association for the controller (Failures 8, 9 from previous run)
  has_many :assigned_event_admins, -> { where(role: EventAssignment.roles[:event_admin]) },
           class_name: 'EventAssignment',
           dependent: :destroy

  # 2. PARTICIPATION
  has_many :tickets, dependent: :destroy

  # 3. SECURITY
  has_many :api_keys, dependent: :destroy
  has_many :email_verifications, dependent: :destroy

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
end
