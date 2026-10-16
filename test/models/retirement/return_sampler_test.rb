require "test_helper"

class Retirement::ReturnSamplerTest < ActiveSupport::TestCase
  test "samples match the requested mean and volatility" do
    samples = Retirement::ReturnSampler.new(mean: 0.07, volatility: 0.15, seed: 1).sample(50_000)
    mean = samples.sum / samples.size
    stdev = Math.sqrt(samples.sum { |r| (r - mean)**2 } / (samples.size - 1))

    assert_in_delta 0.07, mean, 0.005
    assert_in_delta 0.15, stdev, 0.005
    assert samples.all? { |r| r > -1 }
  end

  test "zero volatility returns the mean every year" do
    samples = Retirement::ReturnSampler.new(mean: 0.05, volatility: 0, seed: 1).sample(3)

    samples.each { |r| assert_in_delta 0.05, r, 1e-12 }
  end
end
