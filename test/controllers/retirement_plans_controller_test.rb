require "test_helper"

class RetirementPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @plan = retirement_plans(:dylan_plan)
  end

  test "index goes to the family's plan" do
    get retirement_plans_url
    assert_redirected_to retirement_plan_url(@plan)
  end

  test "index goes to setup when the family has no plan" do
    RetirementPlan.for_family(@user.family).destroy_all

    get retirement_plans_url
    assert_redirected_to new_retirement_plan_url
  end

  test "shows the plan with its open questions" do
    get retirement_plan_url(@plan)

    assert_response :success
    assert_select "h1", @plan.name
    assert_select "a[href=?]", edit_retirement_plan_member_paycheck_path(@plan, retirement_plan_members(:dylan_spouse))
    # Bob's plan matches up to 5% and he defers 4%.
    assert_match "leaves $520.00 a year", response.body
  end

  test "renders the new form" do
    get new_retirement_plan_url
    assert_response :success
  end

  test "creates a one-person plan and links suggested accounts" do
    RetirementPlan.for_family(@user.family).destroy_all

    assert_difference -> { RetirementPlan.count }, 1 do
      post retirement_plans_url, params: { retirement_plan: {
        name: "Solo", filing_status: "single", state: "WI",
        expected_return_percent: "6", inflation_rate_percent: "3", return_volatility_percent: "15",
        withdrawal_rate_percent: "3.5", traditional_tax_rate_percent: "15",
        members_attributes: {
          "0" => { position: 0, name: "Bob", birth_date: "1985-01-01", retirement_age: 60, planning_age: 95 },
          "1" => { position: 1, name: "", birth_date: "", retirement_age: "", planning_age: "95" }
        }
      } }
    end

    plan = RetirementPlan.order(:created_at).last
    assert_redirected_to retirement_plan_url(plan)
    assert_equal 1, plan.members.count
    assert_equal @user.family.primary_currency_code, plan.currency
    assert_in_delta 0.035, plan.withdrawal_rate, 1e-9
    assert_nil plan.annual_spending_override
  end

  test "re-renders the form when invalid" do
    post retirement_plans_url, params: { retirement_plan: { name: "", members_attributes: {} } }
    assert_response :unprocessable_entity
  end

  test "updates the plan and removes the second person" do
    spouse = retirement_plan_members(:dylan_spouse)

    patch retirement_plan_url(@plan), params: { retirement_plan: {
      annual_spending_override: "",
      members_attributes: { "0" => { id: spouse.id, _destroy: "1" } }
    } }

    assert_redirected_to retirement_plan_url(@plan)
    @plan.reload
    assert_nil @plan.annual_spending_override
    assert_equal [ "Bob" ], @plan.members.map(&:name)
  end

  test "destroys the plan" do
    assert_difference -> { RetirementPlan.count }, -1 do
      delete retirement_plan_url(@plan)
    end
  end

  test "another family's plan is not found" do
    sign_in users(:empty)

    get retirement_plan_url(@plan)
    assert_response :not_found
  end
end
