class Profile < ApplicationRecord
  validates :postal_code, presence: true
  validates :province, presence: true
  validates :province, inclusion: {
    in: %w[ON QC BC AB MB SK NS NB NL PE YT NT NU],
      message: "must be a valid Canadian province/territory"
    }

  has_many :coverage_balances, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  has_many :support_tickets, dependent: :destroy

  def benefit_for(category)
    Benefit.where(
      province: province,
      category: category
    ).first
  end

  def get_coverage_balance(category)
    balance = coverage_balances.find_by(category: category)
    return nil unless balance

    {
      category: category,
      remaining_amount: balance.remaining_amount,
      reset_date: balance.reset_date,
      rule_version_id: balance.rule_version_id
    }
  end

  def get_benefit_coverage(category)
    benefit = benefit_for(category)
    return nil unless benefit

    benefit.coverage
  end
end
