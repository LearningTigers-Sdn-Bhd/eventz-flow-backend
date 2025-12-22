class ExhibitorKitPolicy < ApplicationPolicy
  def index?
    user.is_org_owner_or_organizer? ||
    (user.is_exhibition_contractor? && user.exhibition_contractor_profile.present?) || # Contractor can see all kits in their assigned events
    (user.exhibitor? && user.event_vendor_assignments.where(type: 'Exhibitor').exists?) # Exhibitor can see their own kit
  end

  def show?
    user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.event_vendor.event) || record.event_vendor.vendor_id == user.id
  end

  def create?
    user.is_org_owner_or_organizer? || (record.event_vendor.present? && record.event_vendor.vendor_id == user.id)
  end

  def update?
    user.is_org_owner_or_organizer? || user.exhibition_contractor_for?(record.event_vendor.event) || record.event_vendor.vendor_id == user.id
  end

  def permitted_attributes_for_create
    return exhibitor_kit_attributes if user.is_org_owner_or_organizer?
    return exhibitor_create_attributes if record.event_vendor&.vendor_id == user.id

    []
  end

  def permitted_attributes_for_update
    if user.is_org_owner_or_organizer? || user.is_event_admin?(record.event)
      exhibitor_kit_attributes
    elsif user.exhibition_contractor_for?(record.event_vendor.event)
      contractor_attributes
    elsif record.event_vendor.present? && record.event_vendor.vendor_id == user.id
      exhibitor_update_attributes
    else
      []
    end
  end

  private

  def exhibitor_kit_attributes
    [
      :booth_number, :booth_type, :booth_dimensions, :side_wall_left_required, :side_wall_right_required,
      :name_on_fascia, :fascia_upgrade_required, :company_name, :company_address, :pic_full_name,
      :pic_contact_number, :pic_email_address, :special_requirements,
      :digital_brochure_link, :qr_code_url, :is_raw_space,
      :indemnity_signed, :indemnity_document_url,
      :payment_status, :amount_paid, :payment_note, :indemnity_link,
      { exhibitor_team_members_attributes: [:id, :full_name, :_destroy] },
      { exhibitor_kit_items_attributes: [:id, :rentable_item_id, :quantity, :agreed_price, :notes, :_destroy] },
      { exhibitor_kit_printings_attributes: [:id, :printing_service_id, :quantity, :agreed_price, :file_reference, :notes, :_destroy] },
      { custom_requests_attributes: [:id, :description, :quantity, :status, :resolved_price, :response_notes, :_destroy] },
      { exhibitor_kit_admin_notes_attributes: [:id, :note, :user_id, :_destroy] }
    ]
  end

  def contractor_attributes
    %i[
      payment_status amount_paid payment_note indemnity_link
    ] + [
      { custom_requests_attributes: [:id, :status, :resolved_price, :response_notes] }
    ]
  end

  def exhibitor_create_attributes
    exhibitor_update_attributes + [:booth_number, :booth_type, :company_name]
  end

  def exhibitor_update_attributes
    [
      :booth_dimensions, :side_wall_left_required, :side_wall_right_required,
      :name_on_fascia, :fascia_upgrade_required, :company_address, :pic_full_name,
      :pic_contact_number, :pic_email_address, :special_requirements,
      :digital_brochure_link, :is_raw_space,
      :indemnity_signed, :indemnity_document_url,
      { exhibitor_team_members_attributes: [:id, :full_name, :_destroy] },
      { exhibitor_kit_items_attributes: [:id, :rentable_item_id, :quantity, :agreed_price, :notes, :_destroy] },
      { exhibitor_kit_printings_attributes: [:id, :printing_service_id, :quantity, :agreed_price, :file_reference, :notes, :_destroy] },
      { custom_requests_attributes: [:id, :description, :quantity, :status, :resolved_price, :response_notes, :_destroy] }
    ]
  end

  class Scope < Scope
    def resolve
      if user.is_org_owner_or_organizer?
        scope.all
      elsif user.is_exhibition_contractor?
        scope.joins(:event_vendor).where(event_vendors: { event_id: user.exhibition_contractor_profile.event_exhibition_contractors.select(:event_id) })
      elsif user.is_vendor?
        scope.where(event_vendor_id: user.event_vendor_assignments.select(:id))
      else
        scope.none
      end
    end
  end
end
