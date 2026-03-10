class EventPaymentGateway < ApplicationRecord
  belongs_to :event

  encrypts :key_secret
  encrypts :webhook_secret

  validates :provider, presence: true
  validates :key_id, presence: true
  validates :key_secret, presence: true
  validates :event_id, uniqueness: { scope: :provider, message: "already has a gateway for this provider" }
end
