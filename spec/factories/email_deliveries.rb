FactoryBot.define do
  factory :email_delivery do
    provider { 'resend' }
    mailer_name { 'TicketMailer' }
    mailer_action { 'confirmation_email' }
    recipient { 'attendee@example.com' }
    recipients { { 'to' => ['attendee@example.com'], 'cc' => [], 'bcc' => [] } }
    subject { 'Your ticket for Test Event' }
    status { 'queued' }
    metadata { {} }

    trait :sent do
      status { 'sent' }
      provider_message_id { "email_#{SecureRandom.hex(8)}" }
      sent_at { Time.current }
    end

    trait :delivered do
      sent
      status { 'delivered' }
      delivered_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      failed_at { Time.current }
      failure_reason { 'provider_error' }
      last_error { 'provider error' }
    end
  end
end
