module Retirement
  # Entry point for callers: one deterministic path at the expected return
  # (the "median-ish" line on a chart) plus the Monte Carlo summary.
  class Projection
    def initialize(scenario, trials: MonteCarlo::DEFAULT_TRIALS, seed: MonteCarlo::DEFAULT_SEED)
      @scenario = scenario
      @trials = trials
      @seed = seed
    end

    def deterministic
      @deterministic ||= Simulator.new(scenario).run(Array.new(scenario.horizon, scenario.expected_return.to_f))
    end

    def monte_carlo
      @monte_carlo ||= MonteCarlo.new(scenario, trials:, seed:).run
    end

    def success_rate
      monte_carlo.success_rate
    end

    private
      attr_reader :scenario, :trials, :seed
  end
end
