class AiIntegration < ApplicationRecord
  has_many :ai_models, dependent: :destroy

  encrypts :api_key

  validates :provider, presence: true, uniqueness: true
  validates :api_url, presence: true,
                     format: {
                       with: URI::DEFAULT_PARSER.make_regexp(%w[https]),
                       message: 'must be a valid HTTPS URL'
                     }
  validates :api_key, presence: true
end
