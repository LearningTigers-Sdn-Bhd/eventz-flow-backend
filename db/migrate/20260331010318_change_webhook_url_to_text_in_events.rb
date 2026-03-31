class ChangeWebhookUrlToTextInEvents < ActiveRecord::Migration[8.0]
  def change
    change_column :events, :webhook_url, :text
  end
end
