FactoryBot.define do
  factory :registration_form_rsvp_setting do
    registration_form
    enabled { false }
    rsvp_required { false }
    rsvp_expires_in_hours { nil }
    review_sla_hours { 48 }
    notify_by_date { nil }
  end
end
