class AddUseEventLeadsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_event_leads, :boolean, default: false, null: false
  end
end
