require "test_helper"

class RetirementPlans::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @plan = retirement_plans(:dylan_plan)
  end

  test "lists accounts with their bucket" do
    get edit_retirement_plan_accounts_url(@plan)

    assert_response :success
    assert_select "input[type=checkbox][name=?][checked]", "accounts[#{accounts(:investment).id}][included]"
    assert_select "input[name=?]", "accounts[#{accounts(:property).id}][included]", count: 0
  end

  test "tags, adds and removes accounts" do
    patch retirement_plan_accounts_url(@plan), params: { accounts: {
      accounts(:investment).id => { included: "1", tax_bucket: "roth" },
      accounts(:depository).id => { included: "1", tax_bucket: "" }
    } }

    assert_redirected_to retirement_plan_url(@plan)
    links = @plan.account_links.reload.index_by(&:account_id)
    assert_equal "roth", links[accounts(:investment).id].tax_bucket
    assert_nil links[accounts(:depository).id].tax_bucket

    patch retirement_plan_accounts_url(@plan), params: { accounts: {
      accounts(:investment).id => { included: "0" }
    } }
    assert_not @plan.account_links.reload.exists?(account: accounts(:investment))
  end

  test "ignores accounts the user cannot see" do
    other = accounts(:investment).dup.tap { |a| a.family = families(:empty) }
    other.save!(validate: false)

    patch retirement_plan_accounts_url(@plan), params: { accounts: { other.id => { included: "1" } } }
    assert_not @plan.account_links.exists?(account: other)
  end
end
