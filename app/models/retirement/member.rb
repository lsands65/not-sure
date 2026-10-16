module Retirement
  # A person covered by the plan. Ages are whole calendar-year ages.
  Member = Data.define(:name, :birth_year, :retirement_age, :planning_age) do
    def age_in(year) = year - birth_year
    def alive_in?(year) = age_in(year) <= planning_age
    def retired_in?(year) = age_in(year) >= retirement_age
  end
end
