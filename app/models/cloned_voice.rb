class ClonedVoice < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  belongs_to :event, optional: true
  belongs_to :creator, class_name: 'User'

  has_many_attached :audio_samples

  enum :status, { pending: 0, ready: 1, failed: 2 }

  validates :name, presence: true
  validates :status, presence: true
  validates :elevenlabs_id, uniqueness: true, allow_nil: true

  # Default ElevenLabs settings for multilingual v2
  before_validation :set_default_settings, if: :new_record?

  private

  def set_default_settings
    default_settings = {
      stability: 0.4,       # Slightly more expressive/emotive
      similarity_boost: 0.75,
      style: 0.2,           # Increased style exaggeration for more "happy" tone
      use_speaker_boost: true
    }.stringify_keys

    self.settings = default_settings.merge(self.settings || {})
  end
end
