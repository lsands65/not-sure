# Is a member deferring enough to collect the employer's full match?
# Answers nil (with the inputs it needs) instead of guessing.
class RetirementPlan::MatchCheck
  Result = Data.define(:status, :deferral_rate, :needed_rate, :annual_match, :annual_match_missed, :missing_inputs) do
    def captured? = status == :captured
  end

  def initialize(member)
    @member = member
  end

  def result
    employer_plan = member.employer_plan
    paycheck = member.paycheck

    missing = []
    missing << :paycheck if paycheck.nil?
    missing << :employer_plan if employer_plan.nil?
    missing << :match_formula if employer_plan && !employer_plan.match_formula_known?
    return Result.new(status: :unknown, deferral_rate: nil, needed_rate: nil, annual_match: nil, annual_match_missed: nil, missing_inputs: missing) if missing.any?

    deferral = paycheck.deferral_rate
    needed = employer_plan.full_match_deferral_rate
    base_pay = paycheck.annual(:gross_pay)

    annual_match = employer_plan.employer_rate_for(deferral) * base_pay
    full_match = employer_plan.employer_rate_for(needed) * base_pay

    Result.new(
      status: deferral >= needed ? :captured : :missing_match,
      deferral_rate: deferral,
      needed_rate: needed,
      annual_match: annual_match,
      annual_match_missed: [ full_match - annual_match, 0 ].max,
      missing_inputs: []
    )
  end

  private
    attr_reader :member
end
