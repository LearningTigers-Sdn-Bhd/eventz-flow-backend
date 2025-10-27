class EventLocation < ApplicationRecord
  # --- Associations ---
  # An event location belongs to a single event.
  # This matches the 'event_id' column in your schema.
  belongs_to :event, inverse_of: :event_locations

  # An event location can have multiple members assigned to staff that specific location
  # This matches the 'event_location_members' join table in your schema.
  # Note: The 'member' column in the join table likely refers to a User.
  has_many :event_location_members, dependent: :destroy
  has_many :members, through: :event_location_members, source: :member # Assuming the join model uses :member_id

  # --- Callbacks ---
  after_commit :send_webhook_notification, on: [:create, :update]

  # --- Validations ---
  validates :name, presence: true
  validates :scan_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Enforce uniqueness for the combination of event_id and name, as per the database index
  validates :name, uniqueness: { scope: :event_id, message: "already exists for this event" }
  
  # --- Scopes ---
  scope :active, -> { where('scan_limit > 0') }

  def send_webhook_notification
    return unless event.present? && event.webhook_url.present?
    
    event_type = determine_event_type
    return if event_type.nil?
    
    WebhookSenderJob.perform_later(event.webhook_url, build_webhook_payload(event_type))
  end

  private

  def determine_event_type
    return 'location.created' if previous_changes[:id].present?
    return 'location.updated' if significant_changes?
    
    nil
  end

  def significant_changes?
    significant_fields = %w[name scan_limit]
    (previous_changes.keys & significant_fields).any?
  end

  def build_webhook_payload(event_type)
    is_creation = event_type == 'location.created'
    
    payload = {
      event_type: event_type,
      webhook_id: SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601,
      api_version: "v1",
      
      location: {
        id: self.id,
        name: self.name,
        scan_limit: self.scan_limit
      },
      
      event: {
        id: event.id,
        title: event.title
      }
    }
    
    # Add full context on creation
    if is_creation
      payload[:location][:created_at] = self.created_at.iso8601
    else
      # Add changes for updates
      payload[:changes] = format_changes
    end
    
    payload.compact
  end

  def format_changes
    self.previous_changes.except('updated_at').transform_values do |change|
      {
        from: change[0],
        to: change[1]
      }
    end
  end
end
