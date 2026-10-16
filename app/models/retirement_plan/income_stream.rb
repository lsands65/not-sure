class RetirementPlan::IncomeStream < ApplicationRecord
  KINDS = %w[social_security pension annuity employment rental other].freeze

  belongs_to :retirement_plan, inverse_of: :income_streams
  belongs_to :member, class_name: "RetirementPlan::Member"

  validates :kind, inclusion: { in: KINDS }
  validates :annual_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :start_age, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :end_age, numericality: { only_integer: true, greater_than_or_equal_to: :start_age }, allow_nil: true
  validate :member_belongs_to_plan

  def to_engine(member_index)
    Retirement::IncomeStream.new(
      member_index:,
      annual_amount: annual_amount.to_f,
      start_age:,
      end_age:,
      inflation_adjusted:
    )
  end

  private
    def member_belongs_to_plan
      errors.add(:member, :invalid) if member && member.retirement_plan_id != retirement_plan_id
    end
end
