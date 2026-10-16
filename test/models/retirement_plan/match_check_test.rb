require "test_helper"

class RetirementPlan::MatchCheckTest < ActiveSupport::TestCase
  setup do
    @member = retirement_plan_members(:dylan_primary)
  end

  test "reports the match left on the table" do
    result = @member.match_check

    assert_equal :missing_match, result.status
    assert_in_delta 0.04, result.deferral_rate, 1e-9
    assert_in_delta 0.05, result.needed_rate, 1e-9
    assert_in_delta 3_640, result.annual_match, 0.01
    assert_in_delta 520, result.annual_match_missed, 0.01
  end

  test "captured once the deferral reaches the full-match rate" do
    @member.paycheck.traditional_401k = 200

    result = @member.match_check
    assert result.captured?
    assert_in_delta 0, result.annual_match_missed, 0.01
  end

  test "asks instead of guessing when inputs are missing" do
    result = retirement_plan_members(:dylan_spouse).match_check

    assert_equal :unknown, result.status
    assert_equal %i[paycheck employer_plan], result.missing_inputs
  end
end
