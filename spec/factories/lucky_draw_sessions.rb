FactoryBot.define do
  factory :lucky_draw_session do
    association :event
    title { "Session 1" }
    draw_date { Date.today }
    draw_styles { { style: "wheel", theme: "wireframe" } }
    use_gifts { false }
  end
end
