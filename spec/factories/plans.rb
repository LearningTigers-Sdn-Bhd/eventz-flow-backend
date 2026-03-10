FactoryBot.define do
  factory :plan do
    association :event
    name { "Grand Ballroom Plan" }
    canvas_width { 1000.0 }
    canvas_height { 800.0 }
    pixels_per_unit { 20.0 }
    public_enabled { false }
    settings_json { {} }
  end
end