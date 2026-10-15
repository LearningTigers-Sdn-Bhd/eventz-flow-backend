class AddBusinessMatchingHostLabelToEventEmailSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :event_email_settings, :business_matching_host_label, :string
  end
end
