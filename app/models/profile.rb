class Profile < ApplicationRecord
  validates :postal_code, presence: true
  validates :province, presence: true
  validates :province, inclusion: {
    in: %w[ON QC BC AB MB SK NS NB NL PE YT NT NU],
      message: "must be a valid Canadian province/territory"
    }

  has_many :coverage_balances, dependent: :destroy

  def benefit_for(category)
    Benefit.where(
      province: province,
      category: category
    ).first
  end
end
