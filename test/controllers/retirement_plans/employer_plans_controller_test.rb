require "test_helper"

class RetirementPlans::EmployerPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @plan = retirement_plans(:dylan_plan)
    @spouse = retirement_plan_members(:dylan_spouse)
  end

  test "renders a blank form for a member without a plan" do
    get edit_retirement_plan_member_employer_plan_url(@plan, @spouse)
    assert_response :success
  end

  test "creates an employer plan, keeping unanswered features unknown" do
    patch retirement_plan_member_employer_plan_url(@plan, @spouse), params: { employer_plan: {
      employer_name: "Initech", plan_type: "403b",
      match_rate_1_percent: "50", match_up_to_1_percent: "6",
      roth_option: "true", accepts_rollovers: "false", after_tax_allowed: "",
      vesting_type: "", account_id: ""
    } }

    assert_redirected_to retirement_plan_url(@plan)
    employer_plan = @spouse.reload.employer_plan
    assert_in_delta 0.5, employer_plan.match_rate_1, 1e-9
    assert_in_delta 0.06, employer_plan.match_up_to_1, 1e-9
    assert employer_plan.roth_option
    assert_equal false, employer_plan.accepts_rollovers
    assert_nil employer_plan.after_tax_allowed
    assert_nil employer_plan.vesting_type
  end

  test "re-renders on invalid input" do
    patch retirement_plan_member_employer_plan_url(@plan, @spouse), params: { employer_plan: { match_rate_1_percent: "100" } }
    assert_response :unprocessable_entity
  end

  test "removes the employer plan" do
    member = retirement_plan_members(:dylan_primary)
    delete retirement_plan_member_employer_plan_url(@plan, member)

    assert_redirected_to retirement_plan_url(@plan)
    assert_nil member.reload.employer_plan
  end

  test "another family's member is not found" do
    sign_in users(:empty)

    get edit_retirement_plan_member_employer_plan_url(@plan, @spouse)
    assert_response :not_found
  end
end
