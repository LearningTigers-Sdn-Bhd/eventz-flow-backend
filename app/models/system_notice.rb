# Singleton holding the planned-maintenance heads-up shown as a banner in the
# panel (e.g. "Scheduled update tonight 10 PM"). Unplanned outages are handled
# by the panel itself, since this row can't be read while the backend is down.
class SystemNotice < ApplicationRecord
  MAX_MESSAGE_LENGTH = 300

  validates :message, length: { maximum: MAX_MESSAGE_LENGTH }
  validates :message, presence: true, if: :active

  def self.current
    first || create!
  end

  # What the public banner shows: nothing unless the notice is switched on.
  def public_message
    message if active
  end
end
