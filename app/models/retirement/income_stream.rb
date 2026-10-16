module Retirement
  # Starts at `start_age` of its member and stops after `end_age` (nil = for
  # life) or once the member passes their planning age. A stream that is not
  # inflation-adjusted (most private pensions) is fixed in nominal terms, so
  # it loses real value every year.
  IncomeStream = Data.define(:member_index, :annual_amount, :start_age, :end_age, :inflation_adjusted) do
    def active_for?(member, year)
      age = member.age_in(year)
      member.alive_in?(year) && age >= start_age && (end_age.nil? || age <= end_age)
    end
  end
end
