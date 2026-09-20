class AiModel < ApplicationRecord
  belongs_to :ai_integration

  validates :model_id, presence: true, uniqueness: { scope: :ai_integration_id }

  def default_for?(user)
    user.default_ai_model_id == id
  end
end
