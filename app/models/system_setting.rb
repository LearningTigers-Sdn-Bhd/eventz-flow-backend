# frozen_string_literal: true

# Platform-wide defaults, not scoped to any event. Single row.
class SystemSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
