class NullifyTicketReferenceOnFeedbackResponses < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :feedback_responses, :tickets
    add_foreign_key :feedback_responses, :tickets, on_delete: :nullify
  end
end
