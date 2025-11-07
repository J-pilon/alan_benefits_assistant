class CoverageBalance < ApplicationRecord
  belongs_to :profile
  belongs_to :benefit, foreign_key: :rule_version_id, primary_key: :rule_version_id

  def benefit
    Benefit.find_by(rule_version_id: rule_version_id)
  end
end
