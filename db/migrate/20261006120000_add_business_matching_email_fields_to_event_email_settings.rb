# frozen_string_literal: true

class AddBusinessMatchingEmailFieldsToEventEmailSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :event_email_settings, :business_matching_sender_name, :string
    add_column :event_email_settings, :business_matching_host_invite_subject, :string
    add_column :event_email_settings, :business_matching_host_invite_message, :text
  end
end
