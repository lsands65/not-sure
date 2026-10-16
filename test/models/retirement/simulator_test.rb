require "test_helper"

class Retirement::SimulatorTest < ActiveSupport::TestCase
  # One person, age 60 in 2030, retiring at 62, planned to 64: five years,
  # two working and three in drawdown.
  def build_scenario(**overrides)
    Retirement::Scenario.new(**{
      start_year: 2030,
      members: [ Retirement::Member.new(name: "A", birth_year: 1970, retirement_age: 62, planning_age: 64) ],
      balances: { taxable: 10_000.0, traditional: 50_000.0, roth: 0.0, hsa: 0.0 },
      contributions: [ Retirement::Contribution.new(member_index: 0, bucket: :traditional, annual_amount: 10_000.0) ],
      income_streams: [],
      annual_spending: 20_000.0,
      inflation_rate: 0.0,
      expected_return: 0.0,
      return_volatility: 0.0,
      traditional_tax_rate: 0.25
    }.merge(overrides))
  end

  def simulate(scenario, rate = 0.0)
    Retirement::Simulator.new(scenario).run(Array.new(scenario.horizon, rate))
  end

  test "accumulates then withdraws taxable before traditional, grossing up for tax" do
    result = simulate(build_scenario)

    assert_equal (2030..2034).to_a, result.years.map(&:year)
    assert_equal %i[accumulation accumulation drawdown drawdown drawdown], result.years.map(&:phase)
    assert_in_delta 80_000, result.years[1].balance, 0.01

    first_drawdown = result.years[2]
    assert_in_delta 0, first_drawdown.taxable, 0.01
    assert_in_delta 13_333.33, first_drawdown.withdrawal - 10_000, 0.01
    assert_in_delta 3_333.33, first_drawdown.tax, 0.01

    assert result.success?
    assert_in_delta 3_333.33, result.ending_balance, 0.01
  end

  test "reports the first year the money runs short" do
    result = simulate(build_scenario(annual_spending: 30_000.0))

    assert result.depleted?
    assert_equal 2034, result.depletion_year
    assert_in_delta 27_500, result.years.last.shortfall, 0.01
  end

  test "Roth is spent tax-free before the HSA" do
    result = simulate(build_scenario(balances: { taxable: 0.0, traditional: 0.0, roth: 30_000.0, hsa: 100_000.0 }, contributions: []))

    assert_in_delta 10_000, result.years[2].roth, 0.01
    assert_in_delta 100_000, result.years[2].hsa, 0.01
    assert_in_delta 0, result.years[3].roth, 0.01
    assert_in_delta 90_000, result.years[3].hsa, 0.01
    assert_equal 0, result.years.sum(&:tax)
  end

  test "growth is in real terms" do
    flat = simulate(build_scenario(contributions: [], annual_spending: 0.0, inflation_rate: 0.03), 0.03)
    assert_in_delta 60_000, flat.ending_balance, 0.01

    growing = simulate(build_scenario(contributions: [], annual_spending: 0.0), 0.10)
    assert_in_delta 60_000 * 1.1**5, growing.ending_balance, 0.01
  end

  test "income covers spending and any surplus is saved" do
    stream = Retirement::IncomeStream.new(member_index: 0, annual_amount: 25_000.0, start_age: 62, end_age: nil, inflation_adjusted: true)
    result = simulate(build_scenario(income_streams: [ stream ]))

    assert result.years.select { |y| y.phase == :drawdown }.all? { |y| y.withdrawal.zero? }
    assert_in_delta 10_000 + 3 * 5_000, result.years.last.taxable, 0.01
  end

  test "income that is not inflation-adjusted loses real value" do
    stream = Retirement::IncomeStream.new(member_index: 0, annual_amount: 12_100.0, start_age: 62, end_age: nil, inflation_adjusted: false)
    result = simulate(build_scenario(income_streams: [ stream ], inflation_rate: 0.10), 0.10)

    # 2032 is two years out: 12,100 / 1.1^2 = 10,000 in today's money.
    assert_in_delta 10_000, result.years[2].income, 0.01
  end

  test "a couple draws down only once both are retired, and each stops contributing at their own retirement" do
    members = [
      Retirement::Member.new(name: "A", birth_year: 1970, retirement_age: 61, planning_age: 64),
      Retirement::Member.new(name: "B", birth_year: 1970, retirement_age: 63, planning_age: 64)
    ]
    contributions = [
      Retirement::Contribution.new(member_index: 0, bucket: :taxable, annual_amount: 1_000.0),
      Retirement::Contribution.new(member_index: 1, bucket: :taxable, annual_amount: 2_000.0)
    ]
    result = simulate(build_scenario(members:, contributions:))

    assert_equal [ 3_000, 2_000, 2_000, 0, 0 ], result.years.map(&:contributions)
    assert_equal %i[accumulation accumulation accumulation drawdown drawdown], result.years.map(&:phase)
  end

  test "income before the drawdown phase is not counted" do
    stream = Retirement::IncomeStream.new(member_index: 0, annual_amount: 50_000.0, start_age: 60, end_age: nil, inflation_adjusted: true)
    result = simulate(build_scenario(income_streams: [ stream ]))

    assert_equal [ 0, 0 ], result.years.first(2).map(&:income)
  end

  test "requires a return for every year" do
    assert_raises(ArgumentError) { Retirement::Simulator.new(build_scenario).run([ 0.05 ]) }
  end
end
