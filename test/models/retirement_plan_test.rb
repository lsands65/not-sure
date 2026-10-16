require "test_helper"

class RetirementPlanTest < ActiveSupport::TestCase
  setup do
    @plan = retirement_plans(:dylan_plan)
  end

  test "fixture is valid" do
    assert @plan.valid?
  end

  test "covers one or two people" do
    @plan.members.each(&:mark_for_destruction)
    assert_not @plan.valid?
    assert @plan.errors.added?(:members, :count, count: 2)

    plan = RetirementPlan.new(family: families(:dylan_family), name: "Solo", currency: "USD")
    plan.members.build(name: "Solo", birth_date: Date.new(1990, 1, 1), retirement_age: 60, position: 0)
    assert plan.valid?

    plan.members.build(name: "Two", birth_date: Date.new(1990, 1, 1), retirement_age: 60, position: 1)
    plan.members.build(name: "Three", birth_date: Date.new(1990, 1, 1), retirement_age: 60, position: 1)
    assert_not plan.valid?
  end

  test "infers an account's tax bucket from its Sure subtype" do
    assert_equal :traditional, bucket_for_subtype("401k")
    assert_equal :traditional, bucket_for_subtype("ira")
    assert_equal :roth, bucket_for_subtype("roth_ira")
    assert_equal :hsa, bucket_for_subtype("hsa")
    assert_equal :taxable, bucket_for_subtype("brokerage")
    assert_equal :taxable, RetirementPlan::AccountLink.inferred_bucket_for(accounts(:depository))
  end

  test "an explicit tax bucket overrides the inferred one" do
    link = retirement_plan_account_links(:dylan_brokerage)
    assert_equal :taxable, link.effective_tax_bucket

    link.update!(tax_bucket: "roth")
    assert_equal :roth, link.effective_tax_bucket
    assert_in_delta 10_000, @plan.reload.balances_by_bucket[:roth], 0.01
    assert_equal 0, @plan.balances_by_bucket[:taxable]
  end

  test "spending defaults to the trailing 12 months and can be overridden" do
    assert_equal 60_000, @plan.annual_spending
    assert_equal Money.new(1_500_000, "USD"), @plan.target_portfolio_money

    @plan.annual_spending_override = nil
    assert_equal @plan.trailing_annual_spending, @plan.annual_spending
    assert_operator @plan.annual_spending, :>=, 0
  end

  test "builds an engine scenario from the database" do
    scenario = @plan.scenario(start_year: 2026)

    assert_equal [ "Bob", "Jane" ], scenario.members.map(&:name)
    assert_equal [ 1980, 1982 ], scenario.members.map(&:birth_year)
    assert_in_delta 10_000, scenario.balances[:taxable], 0.01
    assert_equal 0, scenario.balances[:traditional]
    assert_equal [ [ 0, :traditional ], [ 1, :roth ] ],
                 scenario.contributions.map { |c| [ c.member_index, c.bucket ] }.sort
    assert_equal [ 0, 1 ], scenario.income_streams.map(&:member_index).sort
    # Through the year the younger member reaches their planning age.
    assert_equal 2077 - 2026 + 1, scenario.horizon
  end

  test "runs a projection" do
    projection = @plan.projection(trials: 50)

    assert_includes 0.0..1.0, projection.success_rate
    assert_equal projection.monte_carlo.years.size, projection.deterministic.years.size
  end

  test "only links the family's own asset accounts" do
    link = @plan.account_links.build(account: accounts(:credit_card))
    assert_not link.valid?

    other_family_account = accounts(:investment).dup.tap { |a| a.family = families(:empty) }
    other_family_account.save!(validate: false)
    link = @plan.account_links.build(account: other_family_account)
    assert_not link.valid?
  end

  test "contributions and income streams must use the plan's own members" do
    other_plan = RetirementPlan.create!(
      family: families(:dylan_family), name: "Other", currency: "USD",
      members_attributes: [ { name: "X", birth_date: Date.new(1990, 1, 1), retirement_age: 60, position: 0 } ]
    )

    contribution = @plan.contributions.build(member: other_plan.members.first, bucket: "taxable", annual_amount: 1)
    assert_not contribution.valid?

    stream = @plan.income_streams.build(member: other_plan.members.first, kind: "pension", annual_amount: 1, start_age: 65)
    assert_not stream.valid?
  end

  # Family has no has_many for plans (FORK.md), so the foreign key alone must
  # clean up. Checked at the database level on a bare family.
  test "is removed with its family" do
    family = Family.create!(name: "Bare")
    RetirementPlan.create!(
      family:, name: "Solo", currency: "USD",
      members_attributes: [ { name: "X", birth_date: Date.new(1990, 1, 1), retirement_age: 60, position: 0 } ]
    )

    assert_difference -> { RetirementPlan.count }, -1 do
      Family.where(id: family.id).delete_all
    end
  end

  private
    def bucket_for_subtype(subtype)
      RetirementPlan::AccountLink.inferred_bucket_for(Account.new(accountable: Investment.new(subtype:)))
    end
end
