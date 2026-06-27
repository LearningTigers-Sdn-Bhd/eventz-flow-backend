class AddUseCertificateToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_certificate, :boolean, default: false, null: false
  end
end
