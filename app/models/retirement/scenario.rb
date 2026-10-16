module Retirement
  # Pure, database-free inputs to the retirement engine.
  #
  # Every amount is an annual figure in today's money (real terms). The engine
  # never touches ActiveRecord: RetirementPlan#scenario builds one of these
  # from the database, and tests build them by hand.
  Scenario = Data.define(
    :start_year,
    :members,               # [Member], one or two
    :balances,              # { taxable:, traditional:, roth:, hsa: }
    :contributions,         # [Contribution]
    :income_streams,        # [IncomeStream]
    :annual_spending,
    :inflation_rate,
    :expected_return,       # nominal, arithmetic mean
    :return_volatility,     # nominal, standard deviation
    :traditional_tax_rate   # effective rate paid on traditional withdrawals
  ) do
    def end_year
      members.map { |m| m.birth_year + m.planning_age }.max
    end

    def years
      (start_year..end_year).to_a
    end

    def horizon
      years.size
    end

    def starting_balance
      BUCKETS.sum { |bucket| balances.fetch(bucket, 0).to_f }
    end
  end
end
