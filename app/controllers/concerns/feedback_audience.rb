# frozen_string_literal: true

# Organizer feedback endpoints serve one form per audience. `audience=exhibitor`
# picks the exhibitor form; anything else is the ticket-holder form.
module FeedbackAudience
  extend ActiveSupport::Concern

  private

  def feedback_audience
    params[:audience].to_s == 'exhibitor' ? :exhibitor : :ticket
  end

  def audience_form(event)
    feedback_audience == :exhibitor ? event.exhibitor_feedback_form : event.feedback_form
  end
end
