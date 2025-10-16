FactoryBot.define do
  factory :event_team_member do
    # Create associated user and event using their respective factories
    association :user
    association :event
  end
end
