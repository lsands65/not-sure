class RetirementPlan::Member < ApplicationRecord
  belongs_to :retirement_plan, inverse_of: :members

  has_many :contributions, class_name: "RetirementPlan::Contribution", dependent: :destroy
  has_many :income_streams, class_name: "RetirementPlan::IncomeStream", dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :birth_date, presence: true
  validates :position, inclusion: { in: 0...RetirementPlan::MAX_MEMBERS }
  validates :retirement_age, numericality: { only_integer: true, greater_than: 0 }
  validates :planning_age, numericality: { only_integer: true, greater_than: :retirement_age, less_than_or_equal_to: 120 }

  def to_engine
    Retirement::Member.new(name:, birth_year: birth_date.year, retirement_age:, planning_age:)
  end
end
