FactoryBot.define do
  factory :benefit do
    sequence(:rule_version_id) { |n| "v2024-Q1-#{format('%03d', n)}" }
    category { "massage" }
    province { "ON" }
    coverage do
      {
        "version" => rule_version_id,
        "category" => category,
        "province" => province,
        "limits" => {
          "annual_max" => 500.00,
          "per_visit_max" => 100.00,
          "visits_per_year" => 10
        },
        "rules" => [
          {
            "type" => "annual_limit",
            "amount" => 500.00,
            "description" => "Maximum $500 per calendar year"
          },
          {
            "type" => "per_visit_limit",
            "amount" => 100.00,
            "description" => "Maximum $100 per massage session"
          },
          {
            "type" => "visit_limit",
            "count" => 10,
            "description" => "Up to 10 visits per calendar year"
          }
        ],
        "restrictions" => {
          "requires_referral" => false,
          "eligible_providers" => [ "RMT", "Massage Therapist" ],
          "exclusions" => [ "Spa services", "Hot stone massage" ]
        },
        "reset_period" => "calendar_year",
        "last_updated" => "2024-01-15T00:00:00Z"
      }
    end

    trait :vision do
      category { "vision" }
      coverage do
        {
          "version" => rule_version_id,
          "category" => "vision",
          "province" => province,
          "limits" => {
            "annual_max" => 200.00,
            "frames_max" => 150.00,
            "lenses_max" => 100.00,
            "frequency" => "every_24_months"
          },
          "rules" => [
            {
              "type" => "annual_limit",
              "amount" => 200.00,
              "description" => "Maximum $200 every 24 months"
            },
            {
              "type" => "frames_limit",
              "amount" => 150.00,
              "description" => "Up to $150 for frames"
            }
          ],
          "restrictions" => {
            "requires_prescription" => true,
            "eligible_providers" => [ "Optometrist", "Optician" ],
            "exclusions" => [ "Contact lenses", "Sunglasses without prescription" ]
          },
          "reset_period" => "every_24_months",
          "last_updated" => "2024-01-15T00:00:00Z"
        }
      end
    end

    trait :dental do
      category { "dental" }
      coverage do
        {
          "version" => rule_version_id,
          "category" => "dental",
          "province" => province,
          "limits" => {
            "annual_max" => 1500.00,
            "coverage_percentage" => 80,
            "deductible" => 50.00
          },
          "rules" => [
            {
              "type" => "annual_limit",
              "amount" => 1500.00,
              "description" => "Maximum $1,500 per calendar year"
            },
            {
              "type" => "coverage_percentage",
              "percentage" => 80,
              "description" => "80% coverage after deductible"
            }
          ],
          "restrictions" => {
            "requires_referral" => false,
            "eligible_providers" => [ "Dentist", "Dental Hygienist" ],
            "exclusions" => [ "Cosmetic procedures", "Orthodontics" ],
            "dependent_coverage" => true
          },
          "reset_period" => "calendar_year",
          "last_updated" => "2024-01-15T00:00:00Z"
        }
      end
    end

    trait :quebec do
      province { "QC" }
      coverage do
        {
          "version" => rule_version_id,
          "category" => category,
          "province" => "QC",
          "limits" => {
            "annual_max" => 400.00,
            "per_visit_max" => 80.00,
            "visits_per_year" => 8
          },
          "rules" => [
            {
              "type" => "annual_limit",
              "amount" => 400.00,
              "description" => "Maximum $400 per calendar year"
            },
            {
              "type" => "per_visit_limit",
              "amount" => 80.00,
              "description" => "Maximum $80 per massage session"
            }
          ],
          "restrictions" => {
            "requires_referral" => false,
            "eligible_providers" => [ "RMT", "Massage Therapist" ],
            "exclusions" => []
          },
          "reset_period" => "calendar_year",
          "last_updated" => "2024-01-15T00:00:00Z"
        }
      end
    end

    trait :stale do
      updated_at { 91.days.ago }
    end
  end
end
