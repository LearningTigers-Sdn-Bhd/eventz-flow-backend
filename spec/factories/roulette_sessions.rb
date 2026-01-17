FactoryBot.define do
  factory :roulette_session do
    association :event
    association :user
    title { "Prize Roulette Session" }
    draw_date { Faker::Date.forward(days: 30) }
    draw_styles { { style: "wheel", theme: "wireframe" } }
    wrapper_background { { "useImage" => false, "backgroundColor" => "#ffffff" } }
    is_multiple { false }
  end
end
