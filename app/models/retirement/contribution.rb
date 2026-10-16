module Retirement
  # Annual savings into one bucket. Stops once its member retires.
  Contribution = Data.define(:member_index, :bucket, :annual_amount)
end
