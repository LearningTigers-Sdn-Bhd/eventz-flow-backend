class AiModel < ApplicationRecord
  belongs_to :ai_integration

  validates :model_id, presence: true, uniqueness: { scope: :ai_integration_id }

  def make_default!
    transaction do
      AiModel.where(is_default: true).where.not(id: id).update_all(is_default: false)
      update!(is_default: true)
    end
  end
end
