FactoryBot.define do
  factory :exhibitor_team_member_limit do
    association :event
    team_member_limit { 3 }
    extra_team_member_fee { 50.00 }

    trait :unlimited do
      team_member_limit { nil }
    end

    trait :no_extra_fee do
      extra_team_member_fee { 0.00 }
    end

    trait :strict_limit do
      team_member_limit { 2 }
      extra_team_member_fee { 100.00 }
    end
  end
end
