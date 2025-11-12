# Clear existing data (optional - comment out if you want to keep existing data)
puts "Clearing existing data..."
CoverageBalance.destroy_all
Benefit.destroy_all
Profile.destroy_all

# Configuration: Change this to create more profiles
PROFILES_TO_CREATE = 1

puts "Creating benefits..."

# Ontario Benefits
Benefit.find_or_create_by!(rule_version_id: "ON-MASSAGE-2024-V1") do |benefit|
  benefit.category = "massage"
  benefit.province = "ON"
  benefit.coverage = {
    "version" => "2024.1",
    "category" => "massage",
    "province" => "ON",
    "limits" => {
      "annual_max" => 500.00,
      "per_visit_max" => 100.00,
      "visits_per_year" => 10
    },
    "rules" => [
      {
        "type" => "eligibility",
        "description" => "Registered Massage Therapist (RMT) required"
      },
      {
        "type" => "coverage",
        "description" => "Covers therapeutic massage for medical conditions"
      },
      {
        "type" => "limit",
        "description" => "Maximum 10 visits per calendar year"
      }
    ],
    "restrictions" => {
      "eligible_providers" => [ "Registered Massage Therapist (RMT)" ],
      "exclusions" => [ "Spa treatments", "Relaxation massage" ],
      "requires_referral" => false
    },
    "reset_period" => "calendar_year",
    "last_updated" => "2024-01-01"
  }
end

Benefit.find_or_create_by!(rule_version_id: "ON-VISION-2024-V1") do |benefit|
  benefit.category = "vision"
  benefit.province = "ON"
  benefit.coverage = {
    "version" => "2024.1",
    "category" => "vision",
    "province" => "ON",
    "limits" => {
      "annual_max" => 200.00,
      "per_visit_max" => nil,
      "visits_per_year" => nil
    },
    "rules" => [
      {
        "type" => "eligibility",
        "description" => "Eye exam covered once every 24 months"
      },
      {
        "type" => "coverage",
        "description" => "Covers prescription glasses or contact lenses"
      },
      {
        "type" => "limit",
        "description" => "Maximum $200 per 24-month period"
      }
    ],
    "restrictions" => {
      "eligible_providers" => [ "Optometrist", "Ophthalmologist", "Licensed Optician" ],
      "exclusions" => [ "Non-prescription sunglasses", "Cosmetic lenses" ],
      "requires_referral" => false
    },
    "reset_period" => "24_months",
    "last_updated" => "2024-01-01"
  }
end

Benefit.find_or_create_by!(rule_version_id: "ON-DENTAL-2024-V1") do |benefit|
  benefit.category = "dental"
  benefit.province = "ON"
  benefit.coverage = {
    "version" => "2024.1",
    "category" => "dental",
    "province" => "ON",
    "limits" => {
      "annual_max" => 1500.00,
      "per_visit_max" => nil,
      "visits_per_year" => nil
    },
    "rules" => [
      {
        "type" => "eligibility",
        "description" => "Licensed dentist or dental hygienist required"
      },
      {
        "type" => "coverage",
        "description" => "100% coverage for preventive care, 80% for basic, 50% for major"
      },
      {
        "type" => "limit",
        "description" => "Maximum $1,500 per calendar year"
      }
    ],
    "restrictions" => {
      "eligible_providers" => [ "Licensed Dentist", "Dental Hygienist" ],
      "exclusions" => [ "Cosmetic procedures", "Teeth whitening" ],
      "requires_referral" => false
    },
    "reset_period" => "calendar_year",
    "last_updated" => "2024-01-01"
  }
end

# Quebec Benefits (example for multi-province support)
Benefit.find_or_create_by!(rule_version_id: "QC-MASSAGE-2024-V1") do |benefit|
  benefit.category = "massage"
  benefit.province = "QC"
  benefit.coverage = {
    "version" => "2024.1",
    "category" => "massage",
    "province" => "QC",
    "limits" => {
      "annual_max" => 400.00,
      "per_visit_max" => 80.00,
      "visits_per_year" => 8
    },
    "rules" => [
      {
        "type" => "eligibility",
        "description" => "Licensed Massage Therapist required"
      },
      {
        "type" => "coverage",
        "description" => "Covers therapeutic massage"
      },
      {
        "type" => "limit",
        "description" => "Maximum 8 visits per calendar year"
      }
    ],
    "restrictions" => {
      "eligible_providers" => [ "Licensed Massage Therapist" ],
      "exclusions" => [ "Spa treatments" ],
      "requires_referral" => false
    },
    "reset_period" => "calendar_year",
    "last_updated" => "2024-01-01"
  }
end

puts "Created #{Benefit.count} benefits"

# Sample profile data
SAMPLE_PROFILES = [
  { postal_code: "M5H 2N2", province: "ON" },
  { postal_code: "H3Z 2Y7", province: "QC" },
  { postal_code: "V6B 1A1", province: "BC" },
  { postal_code: "T2P 2M5", province: "AB" },
  { postal_code: "K1A 0A9", province: "ON" }
]

puts "Creating #{PROFILES_TO_CREATE} profile(s)..."

PROFILES_TO_CREATE.times do |i|
  profile_data = SAMPLE_PROFILES[i % SAMPLE_PROFILES.length]

  profile = Profile.find_or_create_by!(
    postal_code: profile_data[:postal_code],
    province: profile_data[:province]
  )

  puts "  Created profile in #{profile.province} (#{profile.postal_code})"

  # Create coverage balances for this profile
  # Find all benefits for this profile's province
  province_benefits = Benefit.where(province: profile.province)

  province_benefits.each do |benefit|
    # Create a coverage balance with some usage
    annual_max = benefit.coverage.dig("limits", "annual_max") || 0
    remaining_amount = annual_max * 0.7 # 70% remaining (30% used)
    reset_date = Date.today.end_of_year

    CoverageBalance.find_or_create_by!(
      profile: profile,
      category: benefit.category,
      rule_version_id: benefit.rule_version_id
    ) do |balance|
      balance.remaining_amount = remaining_amount
      balance.reset_date = reset_date
    end

    puts "    Created coverage balance: #{benefit.category} - $#{remaining_amount.round(2)} remaining"
  end
end

puts "\nSeed completed successfully!"
puts "   Profiles: #{Profile.count}"
puts "   Benefits: #{Benefit.count}"
puts "   Coverage Balances: #{CoverageBalance.count}"
