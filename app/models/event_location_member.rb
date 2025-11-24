class EventLocationMember < ApplicationRecord
  # The schema indicates a 'member_id' column, which refers to a User
  belongs_to :member, class_name: 'User'
  
  # The schema indicates an 'event_location_id' column
  belongs_to :event_location

  # A user can only be assigned to a specific location once.
  validates :member_id, uniqueness: { scope: :event_location_id }
  
  # Validate that member is either staff or vendor
  validate :member_must_be_staff_or_vendor

  private

  def member_must_be_staff_or_vendor
    return unless member
    
    valid_roles = ['org_owner', 'organizer', 'member', 'vendor']
    unless valid_roles.include?(member.role)
      errors.add(:member, "must be a staff member or vendor (invalid role: #{member.role})")
    end
  end
end