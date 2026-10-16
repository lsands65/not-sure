require "test_helper"

class Retirement::MonteCarloTest < ActiveSupport::TestCase
  def build_scenario(**overrides)
    Retirement::Scenario.new(**{
      start_year: 2030,
      members: [ Retirement::Member.new(name: "A", birth_year: 1970, retirement_age: 65, planning_age: 95) ],
      balances: { taxable: 200_000.0, traditional: 800_000.0, roth: 100_000.0, hsa: 0.0 },
      contributions: [ Retirement::Contribution.new(member_index: 0, bucket: :traditional, annual_amount: 25_000.0) ],
      income_streams: [ Retirement::IncomeStream.new(member_index: 0, annual_amount: 30_000.0, start_age: 67, end_age: nil, inflation_adjusted: true) ],
      annual_spending: 70_000.0,
      inflation_rate: 0.025,
      expected_return: 0.07,
      return_volatility: 0.15,
      traditional_tax_rate: 0.15
    }.merge(overrides))
  end

  test "with no volatility every trial matches the deterministic path" do
    scenario = build_scenario(return_volatility: 0.0)
    deterministic = Retirement::Projection.new(scenario).deterministic
    result = Retirement::MonteCarlo.new(scenario, trials: 5).run

    assert_equal (deterministic.success? ? 1.0 : 0.0), result.success_rate
    result.bands.each_value do |balances|
      balances.zip(deterministic.balances).each { |mc, det| assert_in_delta det, mc, 0.01 }
    end
  end

  test "is reproducible for a given seed" do
    scenario = build_scenario
    first = Retirement::MonteCarlo.new(scenario, trials: 200, seed: 7).run
    second = Retirement::MonteCarlo.new(scenario, trials: 200, seed: 7).run

    assert_equal first, second
  end

  test "success rate falls as spending rises" do
    modest = Retirement::MonteCarlo.new(build_scenario(annual_spending: 50_000.0), trials: 300).run
    lavish = Retirement::MonteCarlo.new(build_scenario(annual_spending: 150_000.0), trials: 300).run

    assert_operator modest.success_rate, :>, lavish.success_rate
    assert_not_nil lavish.median_depletion_year
  end

  test "bands are ordered and cover every year" do
    scenario = build_scenario
    result = Retirement::MonteCarlo.new(scenario, trials: 300).run

    assert_equal scenario.years, result.years
    result.bands.each_value { |balances| assert_equal scenario.horizon, balances.size }
    result.years.each_index do |i|
      values = Retirement::MonteCarlo::PERCENTILES.map { |p| result.band(p)[i] }
      assert_equal values.sort, values
    end
  end
end
