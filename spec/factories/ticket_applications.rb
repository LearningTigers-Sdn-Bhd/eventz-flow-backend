FactoryBot.define do
  factory :ticket_application do
    ticket
    registration_form { association(:registration_form, event: ticket.event) }
    review_status { :pending_review }
    rsvp_status { :not_sent }
    reviewed_by { nil }
    reviewed_at { nil }
    rejection_reason { nil }
    rsvp_token_digest { nil }
    rsvp_sent_at { nil }
    rsvp_confirmed_at { nil }
    rsvp_expires_at { nil }
  end
end
