# Namespace for the fork-only retirement planner. See docs/llm-guides/retirement.md.
module Retirement
  # Tax buckets the engine tracks, in the order drawdown spends them:
  # taxable brokerage first, then traditional (pre-tax, taxed on withdrawal),
  # then Roth, with the HSA last so it can keep compounding tax-free.
  # Every linked account lands in exactly one; see RetirementPlan::AccountLink.
  BUCKETS = %i[taxable traditional roth hsa].freeze
end
