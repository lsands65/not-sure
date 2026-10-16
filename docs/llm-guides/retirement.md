# Retirement planning (fork-only)

Reference for the retirement planner this fork adds on top of Sure. Read
[FORK.md](../../FORK.md) first. It sets the rules that keep this code from
getting in the way of upstream merges.

## Architecture

The planner has three layers. Only the middle one knows about ActiveRecord.

```text
Sure data (accounts, transactions, Money)
  │  read through public methods only
  ▼
RetirementPlan + children (persistence)       app/models/retirement_plan*.rb
  │  #scenario → Retirement::Scenario (plain Data, today's money)
  ▼
Retirement engine (pure Ruby)                 app/models/retirement/*.rb
  Simulator     one path, year by year, given a return sequence
  ReturnSampler seeded lognormal returns
  MonteCarlo    N sampled paths → success rate + percentile bands
  Projection    deterministic path + Monte Carlo, the caller's entry point
```

The engine never touches the database, which keeps it fast and makes exact
assertions possible in tests. Everything a feature needs from Sure must be
turned into a field on `Retirement::Scenario`.

## Data model

| Table | Purpose |
| --- | --- |
| `retirement_plans` | Family-scoped assumptions: return and volatility, inflation, withdrawal rate, traditional-withdrawal tax rate, optional spending override. A family can hold several plans, which become saved scenarios (Tier 2). |
| `retirement_plan_members` | One or two people (`position` 0/1, enforced in the database): date of birth, retirement age, planning age (life expectancy). |
| `retirement_plan_contributions` | Annual savings per member into one bucket. Stops at that member's retirement. |
| `retirement_plan_income_streams` | Social Security, pension, annuity, etc. for one member, from `start_age` (the claiming age, for Social Security) to optional `end_age`, either inflation-adjusted or fixed nominal. |
| `retirement_plan_account_links` | Which Sure accounts fund the plan, with an optional explicit `tax_bucket`. |

Every foreign key into an upstream table cascades on delete. Upstream models
have no associations to these tables.

### Tax buckets

`Retirement::BUCKETS` is `taxable → traditional → roth → hsa`, which is also
the order drawdown spends them in.

- `AccountLink#effective_tax_bucket` returns the explicit `tax_bucket` if one
  is set, and otherwise infers a bucket from Sure's subtype metadata
  (`Account#tax_treatment`):
  - `tax_deferred` → traditional
  - `tax_exempt` or `tax_advantaged` → roth
  - subtype `hsa` → hsa
  - anything else → taxable
- Generic subtypes ("Retirement", "Other") can't be classified reliably, so
  the UI should ask the user to tag them.

## Engine rules (invariants)

- **Real terms throughout.** Amounts are today's money. A year's real return is
  `(1 + nominal) / (1 + inflation) - 1`. Income that isn't inflation-adjusted
  is divided by `(1 + inflation)^years_elapsed`.
- **Yearly order:** contributions, then drawdown, then growth. Changing this
  order changes every figure. Update the simulator tests deliberately if you do.
- **Drawdown starts when every living member is retired.** Until then, the
  model assumes the household lives on earnings and ignores income streams,
  including a retired spouse's pension. This is conservative on purpose.
- **Only traditional withdrawals are taxed**, at a flat effective rate, and they
  are grossed up to net the amount needed. Taxable withdrawals are treated as
  tax-free until Tier 3 adds basis and capital gains.
- **Depletion** is the first year with an unmet need above half a cent.
  Rounding noise from the gross-up must not count as failure.
- **Monte Carlo is seeded** (`MonteCarlo::DEFAULT_SEED`), so the same plan
  always gives the same result and tests can assert exact values. Returns are
  independent lognormal draws whose arithmetic mean and standard deviation
  match the plan.
- **Spending:** `RetirementPlan#annual_spending` is the override if set,
  otherwise `trailing_annual_spending`, which is total expenses over the last
  12 months via `Family#income_statement`.

## Roadmap

### Tier 1: the core planner

| Feature | Status and approach |
| --- | --- |
| Retirement target from real spending | **Partly done:** trailing-12-month total and `target_portfolio_money`. Next: split essential from discretionary. Store the essential flag per category in a fork table (`retirement_category_classifications`, keyed by family and category) rather than a column on `categories`. Exclude transfers into linked accounts, then target `essential / withdrawal_rate` alongside the full figure. |
| Planner inputs page | **Data model done.** Next: `RetirementPlansController`, routes in `config/routes/retirement.rb`, a form built from `DS::*` components with nested members, contributions and income streams. Social Security = an income stream with `kind: social_security` and `start_age` = claiming age. |
| Account tax buckets | **Done in the data model** (`AccountLink#tax_bucket` with inference). Next: a tagging UI on the plan page. |
| Monte Carlo with a fan chart | **Engine done.** Next: a `RetirementProjectionJob` that runs `plan.projection` and caches the summary (success rate, p10/p50/p90 bands, deterministic path) in a `retirement_projections` table keyed by plan and an input digest. Recompute when inputs or balances change, plus nightly. Chart: a D3 Stimulus controller modeled on `goal_projection_chart_controller.js`. |
| Savings-rate sensitivity | **Next.** `Scenario` is a `Data`, so each variant is a `scenario.with(...)` change (extra $500/month in contributions, retirement age + 2, and so on) run through `Projection`. Run variants with fewer trials and the same seed so differences come from the inputs, not sampling noise. |

### Tier 2: depth

- **Historical backtesting.** `Simulator#run` already takes any return
  sequence. Add a yearly real-returns dataset (for example, a stock/bond mix
  since 1928) as a fixture-like data file and roll every start year through it.
- **Withdrawal strategies** (fixed %, guardrails, variable percentage
  withdrawal). Pull the drawdown step in `Simulator#simulate_year` out into
  strategy objects that decide the year's spending from the portfolio state.
  Fixed real spending is today's behavior.
- **Contribution tracker.** Store yearly IRS limits (401(k), IRA, HSA, catch-up
  amounts) in a config table, never as constants. Store the employer match on
  the contribution row.
- **Allocation versus target**, drift and weighted expense ratio, using Sure
  holdings and securities.
- **Milestones** (Coast, Lean and Full FIRE) derived from `annual_spending`,
  the essential subset and `withdrawal_rate`.
- **Scenario comparison.** Several plans per family are already allowed. Add
  a "duplicate plan" action and a side-by-side view.

### Tier 3: more depth

- Roth conversions and tax-bracket filling. This needs a real tax model:
  federal brackets plus **Wisconsin** state tax. Replace the flat
  `traditional_tax_rate` with a tax calculator object behind the same
  interface.
- Pre-Medicare healthcare costs for early retirement: an age-banded expense
  stream until 65.
- Paying off the mortgage versus investing, and the effect of a big purchase
  on the retirement date. Both are sensitivity variants with one-off cash
  flows, which needs a dated lump-sum input type.
- A net-worth milestone timeline, projected versus actual, using Sure's
  balance history.

## Testing

- Engine: `test/models/retirement/`. Build scenarios by hand. Use zero returns
  and zero inflation for exact arithmetic, and zero volatility to check that
  Monte Carlo agrees with the deterministic path.
- Persistence: `test/models/retirement_plan_test.rb`, with fixtures in
  `test/fixtures/retirement_plans.yml` and `test/fixtures/retirement_plan/`.
