class AddBusinessMatchingWebhookUrlToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_webhook_url, :string
  end
end
