require "test_helper"

class RetirementPlans::PaychecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @plan = retirement_plans(:dylan_plan)
    @spouse = retirement_plan_members(:dylan_spouse)
  end

  test "renders a blank form" do
    get edit_retirement_plan_member_paycheck_url(@plan, @spouse)
    assert_response :success
  end

  test "saves a paycheck, treating blank deductions as zero" do
    patch retirement_plan_member_paycheck_url(@plan, @spouse), params: { paycheck: {
      pay_frequency: "semimonthly", gross_pay: "3000", traditional_401k: "300", roth_401k: "", hsa: "50"
    } }

    assert_redirected_to retirement_plan_url(@plan)
    paycheck = @spouse.reload.paycheck
    assert_equal 72_000, paycheck.annual_gross
    assert_equal 0, paycheck.roth_401k
  end

  test "re-renders when deductions exceed gross pay" do
    patch retirement_plan_member_paycheck_url(@plan, @spouse), params: { paycheck: { gross_pay: "100", traditional_401k: "200" } }
    assert_response :unprocessable_entity
  end

  test "removes the paycheck" do
    member = retirement_plan_members(:dylan_primary)
    delete retirement_plan_member_paycheck_url(@plan, member)

    assert_nil member.reload.paycheck
  end
end
