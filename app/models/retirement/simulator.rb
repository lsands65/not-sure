module Retirement
  # Runs one path of a Scenario, one calendar year at a time, against a given
  # sequence of nominal annual returns. Deterministic and Monte Carlo
  # projections are both built on this; it is the only place the yearly
  # cash-flow rules live.
  #
  # Each year, in order:
  #   1. Contributions from members who are still working go into their bucket.
  #   2. Once every living member is retired (the drawdown phase), the gap
  #      between spending and active income is withdrawn: taxable first, then
  #      traditional (grossed up for tax), then Roth, then HSA. Income above
  #      spending is saved into the taxable bucket.
  #   3. Every bucket earns that year's real return.
  #
  # Everything is in today's money: returns are deflated by inflation, and
  # only non-inflation-adjusted income loses value over time.
  class Simulator
    Year = Data.define(
      :year, :ages, :phase,
      :contributions, :income, :spending, :withdrawal, :tax, :shortfall,
      :taxable, :traditional, :roth, :hsa
    ) do
      def balance = taxable + traditional + roth + hsa
    end

    Result = Data.define(:years) do
      def depleted? = depletion_year.present?
      def success? = !depleted?
      def depletion_year = years.find { |y| y.shortfall.positive? }&.year
      def ending_balance = years.last.balance
      def balances = years.map(&:balance)
    end

    def initialize(scenario)
      @scenario = scenario
    end

    def run(nominal_returns)
      raise ArgumentError, "need #{scenario.horizon} returns, got #{nominal_returns.size}" if nominal_returns.size < scenario.horizon

      buckets = Retirement::BUCKETS.index_with { |bucket| scenario.balances.fetch(bucket, 0).to_f }

      years = scenario.years.each_with_index.map do |year, index|
        simulate_year(year, index, buckets, nominal_returns[index])
      end

      Result.new(years:)
    end

    private
      attr_reader :scenario

      def simulate_year(year, index, buckets, nominal_return)
        contributions = contribute(year, buckets)
        income = income_in(year, index)
        drawdown = drawdown_phase?(year)

        spending = 0.0
        withdrawal = tax = shortfall = 0.0

        if drawdown
          spending = scenario.annual_spending.to_f
          gap = spending - income

          if gap.positive?
            withdrawal, tax, shortfall = withdraw(gap, buckets)
          else
            buckets[:taxable] += -gap
          end
        end

        real_return = (1 + nominal_return) / (1 + scenario.inflation_rate.to_f) - 1
        buckets.transform_values! { |balance| balance * (1 + real_return) }

        Year.new(
          year:,
          ages: scenario.members.map { |m| m.age_in(year) },
          phase: drawdown ? :drawdown : :accumulation,
          contributions:, income:, spending:, withdrawal:, tax:, shortfall:,
          **buckets
        )
      end

      def drawdown_phase?(year)
        living = scenario.members.select { |m| m.alive_in?(year) }
        living.any? && living.all? { |m| m.retired_in?(year) }
      end

      def contribute(year, buckets)
        scenario.contributions.sum do |contribution|
          member = scenario.members.fetch(contribution.member_index)
          next 0.0 if member.retired_in?(year) || !member.alive_in?(year)

          amount = contribution.annual_amount.to_f
          buckets[contribution.bucket.to_sym] += amount
          amount
        end
      end

      # Income before the drawdown phase is ignored: while someone still works
      # we assume the household lives on earnings, and we do not count a
      # retired spouse's pension as extra savings. Conservative on purpose.
      def income_in(year, index)
        return 0.0 unless drawdown_phase?(year)

        scenario.income_streams.sum do |stream|
          member = scenario.members.fetch(stream.member_index)
          next 0.0 unless stream.active_for?(member, year)

          amount = stream.annual_amount.to_f
          amount /= (1 + scenario.inflation_rate.to_f)**index unless stream.inflation_adjusted
          amount
        end
      end

      # Spends buckets in BUCKETS order. Only traditional withdrawals are
      # taxed, so they are grossed up to net the amount needed. Taxable
      # withdrawals are treated as tax-free (basis + long-term gains is a
      # Tier 3 refinement). Returns [gross withdrawn, tax paid, unmet need].
      def withdraw(need, buckets)
        withdrawn = 0.0
        tax = 0.0

        Retirement::BUCKETS.each do |bucket|
          break unless need.positive?
          next unless buckets[bucket].positive?

          rate = bucket == :traditional ? scenario.traditional_tax_rate.to_f : 0.0
          gross = [ need / (1 - rate), buckets[bucket] ].min
          buckets[bucket] -= gross
          withdrawn += gross
          tax += gross * rate
          need -= gross * (1 - rate)
        end

        # Float dust from the gross-up must not read as a depletion.
        need = 0.0 if need < 0.005
        [ withdrawn, tax, need ]
      end
  end
end
