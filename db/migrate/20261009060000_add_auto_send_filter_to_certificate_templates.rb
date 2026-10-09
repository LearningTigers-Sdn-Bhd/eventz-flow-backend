# frozen_string_literal: true

class AddAutoSendFilterToCertificateTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_templates, :auto_send_filter, :jsonb, default: {}, null: false
  end
end
