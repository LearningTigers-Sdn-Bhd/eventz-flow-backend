class AddUniqueTicketIndexToFeedbackResponses < ActiveRecord::Migration[8.0]
  def change
    # One response per ticket per form; anonymous (NULL ticket) rows stay unrestricted.
    add_index :feedback_responses, %i[feedback_form_id ticket_id], unique: true
  end
end
