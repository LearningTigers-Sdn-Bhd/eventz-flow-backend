FactoryBot.define do
  factory :exhibitor_zone_quota do
    event
    zone { "zone_d" }
    quota { 103 }
  end
end
