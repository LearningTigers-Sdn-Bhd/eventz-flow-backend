# frozen_string_literal: true

class AddWelcomeTextToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :welcome_text, :string, default: "Welcome"
  end
end
