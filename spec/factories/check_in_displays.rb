# frozen_string_literal: true

FactoryBot.define do
  factory :check_in_display do
    association :event
    font_family { 'Inter' }
    font_size { 72 }
    animation_type { :fade_in }
    is_bold { false }
    name_color { '#FFFFFF' }

    trait :with_custom_settings do
      font_family { 'Roboto' }
      font_size { 96 }
      animation_type { :slide_up }
      is_bold { true }
      name_color { '#FFD700' }
    end

    trait :no_animation do
      animation_type { :no_animation }
    end
  end
end
