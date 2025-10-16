# app/models/user.rb

class User < ApplicationRecord
  # --- Authentication ---
  has_secure_password

  # --- Roles (Finalized and Future-Proofed) ---
  # 0: org_owner (System Owner/Superadmin)
  # 1: manager (Event Organizer/Admin)
  # 2: member (Standard User/Participant)
  enum :role, { org_owner: 0, manager: 1, member: 2 }

  # Ensures new users default to the lowest privilege role
  after_initialize :set_default_role, if: :new_record?

  # --- Validations ---
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
  validates :full_name, presence: true # Assuming full_name is required

  # --- Associations (The user is linked to events via THREE distinct ways) ---
  
  # 1. Management/Ownership: Events where the user is an assigned organizer (Event Admin)
  has_many :event_admins, dependent: :destroy
  has_many :assigned_events, through: :event_admins, source: :event


  # 2. Staff/Scanning Access: Events where the user is a team member
  has_many :event_team_members, dependent: :destroy
  has_many :staffed_events, through: :event_team_members, source: :event # Renamed for clarity

  # 3. Participation: Tickets bought by the user
  has_many :tickets, dependent: :destroy # Links user to events they bought tickets for

  has_many :refresh_tokens, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  # NOTE: The original `has_many :events, dependent: :destroy` is removed. 
  # In our current design, users don't directly own events; they are assigned via EventAdmin. 
  # Direct ownership would require an `owner_id` column on the `events` table, which is redundant 
  # when `EventAdmin` serves as the ownership link.

  # --- Role Helper Methods (Directly checking the ENUM value) ---

  # Checks if the user is the highest system authority
  def is_org_owner?
    org_owner? # Use the Rails enum helper method
  end

  # Checks if the user is a high-level manager (Org Owner or Manager)
  # This is usually used for permissions like 'Can view all reports/users in the org'
  def is_manager_or_higher?
    org_owner? || manager?
  end

  # Checks if the user has the base system manager role (Event Organizer)
  def is_manager?
    role.in?(['org_owner', 'manager'])
  end

  # Checks if the user is a standard platform member/participant
  def is_member?
    member?
  end

  def is_event_admin?(event)
    return false unless event.present?
    event_admins.exists?(event_id: event.id)
  end

  def is_event_team_member?(event)
    return false unless event.present?
    event_team_members.exists?(event_id: event.id)
  end

  private

  def set_default_role
    self.role ||= :member
  end
end