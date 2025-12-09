class PrintingService < ApplicationRecord
  belongs_to :item_category
  belongs_to :user

  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true
  validates :unit_of_measure, presence: true
  validates :default_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
end
