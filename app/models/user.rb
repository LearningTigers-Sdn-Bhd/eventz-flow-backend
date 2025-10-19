class User < ApplicationRecord
  # --- Authentication ---
  has_secure_password

  # --- Global Roles ---
  # Rails best practice is to use the provided methods (org_owner?, manager?, etc.)
  # The enum values should remain integers for database consistency.
  enum :role, { org_owner: 0, manager: 1, member: 2 }, scopes: false

  # --- Status ---
  enum :status, { active: 1, inactive: 0 }

  # --- Callbacks ---
  after_initialize :set_default_role, if: :new_record?
  after_initialize :set_default_status, if: :new_record?

  # --- Validations ---
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
  validates :full_name, presence: true
  validates :status, presence: true

  # --- Associations ---
  
  # 1. EVENT STAFFING (Unified Event Assignment Model)
  has_many :event_assignments, dependent: :destroy
  has_many :assigned_events, through: :event_assignments, source: :event

  # Add the required scoped association for the controller (Failures 8, 9 from previous run)
  has_many :assigned_event_admins, -> { where(role: EventAssignment.roles[:event_admin]) }, 
           class_name: 'EventAssignment', 
           dependent: :destroy

  # 2. PARTICIPATION
  has_many :tickets, dependent: :destroy

  # 3. SECURITY
  has_many :refresh_tokens, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  # --- Global Role Helper Methods (FIXED LOGIC) ---
  
  # Ensures Org Owner is included as a Manager
  def is_manager?
    manager? || org_owner?
  end
  
  # Check if a user is an Org Owner or Manager
  def is_org_owner_or_manager?
    is_manager?
  end
  
  # Pure check for Org Owner role
  def is_org_owner?
    org_owner?
  end

  # Pure check for Member role (exclusive of Manager/Owner)
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

  private

  # Use the Rails enum helper methods (org_owner?, manager?, etc.) instead of string comparisons ('manager')
  # when the methods are defined on the User class itself.

  def set_default_role
    # Use the symbol/key provided in the enum definition
    self.role ||= :member
  end

  def set_default_status
    self.status ||= :active
  end
end