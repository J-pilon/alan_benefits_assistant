FactoryBot.define do
  factory :coverage_balance do
    association :profile
    category { "massage" }
    remaining_amount { 350.00 }
    reset_date { Date.new(2025, 1, 1) }
    rule_version_id { "v2024-Q1-001" }

    # Ensure the benefit exists before creating the coverage_balance
    before(:create) do |coverage_balance|
      unless Benefit.exists?(rule_version_id: coverage_balance.rule_version_id)
        create(:benefit, rule_version_id: coverage_balance.rule_version_id, category: coverage_balance.category, province: coverage_balance.profile.province)
      end
    end

    trait :vision do
      category { "vision" }
      remaining_amount { 150.00 }
      rule_version_id { "v2024-Q1-002" }
    end

    trait :dental do
      category { "dental" }
      remaining_amount { 1200.00 }
      rule_version_id { "v2024-Q1-003" }
    end
  end
end
