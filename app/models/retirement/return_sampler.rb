module Retirement
  # Draws independent nominal annual returns from a lognormal distribution
  # whose arithmetic mean and standard deviation match the inputs. Lognormal
  # rather than normal so a year can never lose more than 100%.
  #
  # Seeded, so a given plan produces the same Monte Carlo result on every
  # page load and tests can assert exact figures.
  class ReturnSampler
    def initialize(mean:, volatility:, seed:)
      @random = Random.new(seed)

      gross_mean = 1 + mean.to_f
      @sigma = Math.sqrt(Math.log(1 + (volatility.to_f / gross_mean)**2))
      @mu = Math.log(gross_mean) - @sigma**2 / 2
    end

    def sample(count)
      Array.new(count) { Math.exp(@mu + @sigma * standard_normal) - 1 }
    end

    private
      # Box-Muller transform.
      def standard_normal
        u1 = 1.0 - @random.rand # (0, 1], so log never sees zero
        u2 = @random.rand
        Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math::PI * u2)
      end
  end
end
