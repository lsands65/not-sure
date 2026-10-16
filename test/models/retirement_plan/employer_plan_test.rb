require "test_helper"

class RetirementPlan::EmployerPlanTest < ActiveSupport::TestCase
  setup do
    @plan = retirement_plan_employer_plans(:primary_401k)
  end

  test "employer rate follows a two-tier match" do
    assert_in_delta 0.0, @plan.employer_rate_for(0), 1e-9
    assert_in_delta 0.02, @plan.employer_rate_for(0.02), 1e-9
    assert_in_delta 0.035, @plan.employer_rate_for(0.04), 1e-9
    assert_in_delta 0.04, @plan.employer_rate_for(0.05), 1e-9
    assert_in_delta 0.04, @plan.employer_rate_for(0.15), 1e-9
    assert_in_delta 0.05, @plan.full_match_deferral_rate, 1e-9
  end

  test "non-elective contributions arrive regardless of deferral" do
    @plan.nonelective_rate = 0.03
    assert_in_delta 0.03, @plan.employer_rate_for(0), 1e-9
  end

  test "an unknown formula answers nil rather than zero" do
    @plan.match_rate_1 = nil
    @plan.match_up_to_1 = nil

    assert_nil @plan.employer_rate_for(0.05)
    assert_nil @plan.full_match_deferral_rate
    assert_includes @plan.missing_inputs, :match_rate_1
  end

  test "match tiers must be complete" do
    @plan.match_up_to_2 = nil
    assert_not @plan.valid?
    assert @plan.errors.added?(:match_up_to_2, :blank)
  end

  test "vesting" do
    today = Date.new(2026, 10, 16)
    assert_equal 1, @plan.vested_fraction(on: today)

    @plan.assign_attributes(vesting_type: "cliff", vesting_years: 3, service_start_date: Date.new(2024, 10, 1))
    assert_equal 0, @plan.vested_fraction(on: today)

    @plan.assign_attributes(vesting_type: "graded", vesting_years: 4)
    assert_in_delta 0.5, @plan.vested_fraction(on: today), 1e-9

    @plan.service_start_date = nil
    assert_nil @plan.vested_fraction(on: today)
    assert_includes @plan.missing_inputs, :service_start_date
  end

  test "unanswered yes/no features become questions" do
    assert_empty @plan.missing_inputs

    @plan.accepts_rollovers = nil
    assert_equal [ :accepts_rollovers ], @plan.missing_inputs
  end

  test "percent accessors convert to and from fractions" do
    assert_equal "100", @plan.match_rate_1_percent
    assert_equal "0.05", @plan.expense_ratio_percent

    @plan.match_up_to_1_percent = "4.5"
    assert_in_delta 0.045, @plan.match_up_to_1, 1e-9

    @plan.match_rate_2_percent = ""
    assert_nil @plan.match_rate_2
  end

  test "the linked account must belong to the family" do
    other = accounts(:investment).dup.tap { |a| a.family = families(:empty) }
    other.save!(validate: false)

    @plan.account = other
    assert_not @plan.valid?
  end
end
