module Retirement
  # Runs a Scenario through many random return sequences and summarizes them.
  #
  # Success means the plan never runs short of money before the last member's
  # planning age. The balance bands are per-year percentiles of the total
  # portfolio across all trials, in today's money.
  class MonteCarlo
    DEFAULT_TRIALS = 1_000
    DEFAULT_SEED = 42
    PERCENTILES = [ 10, 25, 50, 75, 90 ].freeze

    Result = Data.define(:trials, :years, :success_rate, :bands, :median_depletion_year) do
      # bands: { 10 => [balance per year], 25 => [...], ... }
      def band(percentile) = bands.fetch(percentile)
    end

    def initialize(scenario, trials: DEFAULT_TRIALS, seed: DEFAULT_SEED)
      @scenario = scenario
      @trials = trials
      @seed = seed
    end

    def run
      simulator = Simulator.new(scenario)
      sampler = ReturnSampler.new(mean: scenario.expected_return, volatility: scenario.return_volatility, seed:)

      results = Array.new(trials) { simulator.run(sampler.sample(scenario.horizon)) }
      successes = results.count(&:success?)
      depletions = results.filter_map(&:depletion_year)

      Result.new(
        trials:,
        years: scenario.years,
        success_rate: successes.fdiv(trials),
        bands: bands_for(results),
        median_depletion_year: depletions.empty? ? nil : percentile(depletions.sort, 50).round
      )
    end

    private
      attr_reader :scenario, :trials, :seed

      def bands_for(results)
        by_year = results.map(&:balances).transpose.map(&:sort)

        PERCENTILES.index_with do |pct|
          by_year.map { |sorted| percentile(sorted, pct) }
        end
      end

      # Linear interpolation between closest ranks.
      def percentile(sorted, pct)
        return sorted.first if sorted.size == 1

        rank = pct / 100.0 * (sorted.size - 1)
        lower = sorted[rank.floor]
        upper = sorted[rank.ceil]
        lower + (upper - lower) * (rank - rank.floor)
      end
  end
end
