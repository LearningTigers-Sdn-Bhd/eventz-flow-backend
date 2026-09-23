class AddRequireFeedbackToCertificateTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_templates, :require_feedback, :boolean, default: false, null: false
  end
end
