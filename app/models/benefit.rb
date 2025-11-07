class Benefit < ApplicationRecord
  validates :rule_version_id, presence: true, uniqueness: true
  validates :category, presence: true
  validates :province, presence: true
  validates :coverage, presence: true

  # Ensure coverage JSONB matches expected structure
  validate :coverage_structure_valid

  scope :by_category, ->(category) { where(category: category) }
  scope :by_province, ->(province) { where(province: province) }
  scope :by_category_and_province, ->(category, province) {
    where(category: category, province: province)
  }
  scope :recent, -> { order(updated_at: :desc) }
  scope :stale, -> { where("updated_at < ?", 90.days.ago) }

  def version
    coverage["version"]
  end

  def annual_max
    coverage.dig("limits", "annual_max")
  end

  def per_visit_max
    coverage.dig("limits", "per_visit_max")
  end

  def visits_per_year
    coverage.dig("limits", "visits_per_year")
  end

  def rule_bullets
    coverage["rules"]&.map { |r| r["description"] } || []
  end

  def why_text
    coverage["rules"]&.map { |r| "#{r["type"]}: #{r["description"]}" }&.join("; ") || ""
  end

  def reset_period
    coverage["reset_period"]
  end

  def eligible_providers
    coverage.dig("restrictions", "eligible_providers") || []
  end

  def exclusions
    coverage.dig("restrictions", "exclusions") || []
  end

  def requires_referral?
    coverage.dig("restrictions", "requires_referral") || false
  end

  def stale?
    updated_at < 90.days.ago
  end

  private

  def coverage_structure_valid
    return if coverage.blank?

    errors.add(:coverage, "must include 'version'") unless coverage["version"].present?
    errors.add(:coverage, "must include 'category'") unless coverage["category"].present?
    errors.add(:coverage, "must include 'province'") unless coverage["province"].present?
    errors.add(:coverage, "must include 'limits'") unless coverage["limits"].present?
    errors.add(:coverage, "must include 'rules'") unless coverage["rules"].present?
    errors.add(:coverage, "must include 'reset_period'") unless coverage["reset_period"].present?
    errors.add(:coverage, "must include 'last_updated'") unless coverage["last_updated"].present?

    if coverage["category"].present? && category.present?
      errors.add(:coverage, "category in JSONB must match category column") unless coverage["category"] == category
    end

    if coverage["province"].present? && province.present?
      errors.add(:coverage, "province in JSONB must match province column") unless coverage["province"] == province
    end
  end
end
