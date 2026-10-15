# frozen_string_literal: true

class CustomFieldQuota < ApplicationRecord
  # "quota" is uncountable per ActiveSupport::Inflector, so the default
  # table-name inference would look for "custom_field_quota" instead of
  # the actual "custom_field_quotas" table — pin it explicitly.
  self.table_name = 'custom_field_quotas'

  belongs_to :event

  validates :field_key, :value, presence: true
  validates :quota, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :value, uniqueness: { scope: %i[event_id field_key] }
end
