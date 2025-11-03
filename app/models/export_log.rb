class ExportLog < ApplicationRecord
  # Disable Single Table Inheritance since we're using 'type' as a regular column
  self.inheritance_column = nil

  # --- Associations ---
  belongs_to :event

  # --- Validations ---
  validates :type, presence: true
  validates :sheet_path, presence: true
  validates :event_id, presence: true
end
