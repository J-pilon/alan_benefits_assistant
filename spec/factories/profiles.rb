FactoryBot.define do
  factory :profile do
    postal_code { "M5H 2N2" }
    province { "ON" }

    trait :quebec do
      postal_code { "H3A 0G4" }
      province { "QC" }
    end

    trait :british_columbia do
      postal_code { "V6B 1A1" }
      province { "BC" }
    end
  end
end
