class RetirementPlan::Member < ApplicationRecord
  belongs_to :retirement_plan, inverse_of: :members

  has_many :contributions, class_name: "RetirementPlan::Contribution", dependent: :destroy
  has_many :income_streams, class_name: "RetirementPlan::IncomeStream", dependent: :destroy
  has_one :employer_plan, class_name: "RetirementPlan::EmployerPlan", inverse_of: :member, dependent: :destroy
  has_one :paycheck, class_name: "RetirementPlan::Paycheck", inverse_of: :member, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :birth_date, presence: true
  validates :position, inclusion: { in: 0...RetirementPlan::MAX_MEMBERS }
  validates :retirement_age, numericality: { only_integer: true, greater_than: 0 }
  validates :planning_age, numericality: { only_integer: true, greater_than: :retirement_age, less_than_or_equal_to: 120 }

  def age(on: Date.current)
    had_birthday = on.month * 100 + on.day >= birth_date.month * 100 + birth_date.day
    on.year - birth_date.year - (had_birthday ? 0 : 1)
  end

  def match_check
    RetirementPlan::MatchCheck.new(self).result
  end

  def to_engine
    Retirement::Member.new(name:, birth_year: birth_date.year, retirement_age:, planning_age:)
  end
end
