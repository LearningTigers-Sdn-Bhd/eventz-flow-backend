FactoryBot.define do
  factory :wish_wall_setting do
    association :event
    display_mode { 'cards' }
    animation_shape { nil }
    animation_text { nil }
    accent_color { nil }
    header_text_color { nil }
    card_background_color { nil }
  end
end
