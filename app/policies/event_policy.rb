class EventPolicy < ApplicationPolicy

    # Helper method to check if the user is an assigned administrator for the event
    def is_event_admin?
        # Check if the user is in the 'admins' association on the Event model
        EventAdmin.exists?(user_id: user.id, event_id: record.id)
    end
    
    # Helper method to check if the user is staff for the event
    def is_event_staff?
        # Check if the user is in the 'team_members' association on the Event model
        EventTeamMember.exists?(user_id: user.id, event_id: record.id)
    end

    def index?
    	user.present?
    end

    # POST /v1/events
    def create?
        user.present? && user.is_org_owner?
    end

    # GET /v1/events/:id
    def show?
        user.is_org_owner? ||
        is_event_admin? ||
        is_event_staff?
    end

    # PATCH/PUT /v1/events/:id
    def update?
        allowed_to_edit = user.is_org_owner? || is_event_admin?

        allowed_to_edit && (user.is_org_owner? || record.paid?)
    end

    # DELETE /v1/events/:id
    def destroy?
        # FIX for the failed test: Allow Org Owners or the event's assigned Administrators to destroy
        # The manager_user needs to be able to destroy their managed/paid event.
        user.is_org_owner? || is_event_admin?
    end

    
    # =========================================================================
    # Scope for Index (GET /v1/events)
    # =========================================================================

    class Scope < Scope
        def resolve
            # FIX: Remove all references to the non-existent events.user_id column.
            # Use the associations defined on the User model for efficiency.
            
            # 1. Events where the user is an assigned admin (assigned_events)
            admin_event_ids = EventAdmin.where(user_id: user.id).select(:event_id)
            
            # 2. Events where the user is a staff/team member (staffed_events)
            staff_event_ids = EventTeamMember.where(user_id: user.id).select(:event_id)
            
            # Combine the two relations and ensure distinct results
            scope.where(id: admin_event_ids).or(scope.where(id: staff_event_ids)).distinct
        end
    end
end