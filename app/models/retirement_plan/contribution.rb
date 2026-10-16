class RetirementPlan::Contribution < ApplicationRecord
  belongs_to :retirement_plan, inverse_of: :contributions
  belongs_to :member, class_name: "RetirementPlan::Member"

  validates :bucket, inclusion: { in: Retirement::BUCKETS.map(&:to_s) }
  validates :annual_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :member_belongs_to_plan

  def to_engine(member_index)
    Retirement::Contribution.new(member_index:, bucket: bucket.to_sym, annual_amount: annual_amount.to_f)
  end

  private
    def member_belongs_to_plan
      errors.add(:member, :invalid) if member && member.retirement_plan_id != retirement_plan_id
    end
end
