class Exhibitor < EventVendor
  # --- Associations ---
  belongs_to :exhibitor_owner, class_name: 'ExhibitorOwner', foreign_key: 'exhibitor_owner_id', optional: true

  # --- Validations ---
  # exhibitor_owner_id is optional - Exhibitors can be independent or owned

  # --- Scopes ---
  scope :owned_by, ->(exhibitor_owner) { where(exhibitor_owner_id: exhibitor_owner.id) }
  scope :independent, -> { where(exhibitor_owner_id: nil) }
  scope :owned, -> { where.not(exhibitor_owner_id: nil) }

  # --- Instance Methods ---
  def exhibitor_owner_name
    exhibitor_owner&.name
  end

  def independent?
    exhibitor_owner_id.nil?
  end

  def owned?
    exhibitor_owner_id.present?
  end

  def can_manage_vendor?(user)
    # Future: Add authorization logic if needed
    # For now, any user with event admin access can manage
    false
  end
end
