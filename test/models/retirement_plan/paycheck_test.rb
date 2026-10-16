require "test_helper"

class RetirementPlan::PaycheckTest < ActiveSupport::TestCase
  setup do
    @paycheck = retirement_plan_paychecks(:primary)
  end

  test "annualizes the stub" do
    assert_equal 26, @paycheck.periods_per_year
    assert_equal 109_000, @paycheck.annual_gross
    assert_in_delta 0.04, @paycheck.deferral_rate, 1e-9
    assert_equal 4_160, @paycheck.annual_employee_deferrals
    assert_equal 7_260, @paycheck.annual_payroll_savings
    assert_equal 10_660, @paycheck.annual_pretax_deductions
  end

  test "deductions cannot exceed gross pay" do
    @paycheck.traditional_401k = 5_000
    assert_not @paycheck.valid?
    assert @paycheck.errors.added?(:base, :deductions_exceed_gross)
  end
end
