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
| `retirement_plan_employer_plans` | One per member: match formula (two tiers plus non-elective), true-up, vesting, plan features as nullable yes/no, expense ratio, optional Sure account. |
| `retirement_plan_paychecks` | One per member, as printed on a pay stub: frequency, gross pay, per-period deductions, plus annual bonus and employer HSA money. |

`retirement_plans` also holds `filing_status` and `state`, both nullable
until the user answers.

Every foreign key into an upstream table cascades on delete, except the
optional employer-plan account link, which is set to null. Upstream models
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
- Generic subtypes ("Retirement", "Pension", "Other", or none) can't be
  classified reliably. `AccountLink#tax_bucket_ambiguous?` flags them so the
  plan page asks the user to tag them.

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

## Inputs and questions

Bank transactions show take-home pay only. Pre-tax 401(k) and HSA savings
never reach a Sure account, so they come from the pay-stub form
(`RetirementPlan::Paycheck`). Employer plan rules come from
`RetirementPlan::EmployerPlan`.

**Missing inputs produce a question, never a silent guess.**

- Yes/no plan features are nullable booleans. In forms they are a
  Yes / No / Not sure select.
- `RetirementPlan#missing_inputs` gathers every unanswered field as a
  `[subject, attribute]` pair. `RetirementPlansHelper#retirement_question`
  turns each pair into a question and a link to the page that answers it.
- Calculations that depend on a missing input return nil or `:unknown`
  rather than a default. `RetirementPlan::MatchCheck` is the pattern to copy.
- Rates are stored as fractions (0.07) and typed as percentages (7) through
  the `RetirementPlan::PercentAttributes` concern (`*_percent` accessors).

**Limits, brackets and phase-outs are never hardcoded.** IRS and state figures
go in dated data files, each recording the tax year it applies to and a "last
verified" date checked against the current IRS publication. Federal and
Wisconsin rules go in separate files.

## Build order

1. **Done:**
   - employer plan form, with match tiers, true-up, vesting and plan features
   - pay-stub form
   - tagging each account's tax bucket
   - filing status and state
   - the plan page, which shows open questions and whether the employer
     match is being captured
2. Savings capacity from Sure's transactions: income minus spending over 6 to
   12 months, excluding transfers and one-offs, plus the payroll savings from
   step 1. Split spending into essential and discretionary, with the essential
   flag per category stored in a fork table, not on `categories`.
3. The account recommendation engine (the "waterfall"), with each rule stored
   as data (`preconditions`, `needs_input`, `flags`, `explanation`) and unit
   tests for every rule.
4. Mapping goals to account types by time horizon.
5. Edge-case rules:
   - backdoor Roth (pro-rata exposure, Form 8606 basis per tax year,
     tax-year attribution)
   - mega backdoor Roth
   - FIRE access: bridge check, conversion ladder, Rule of 55
6. Impact preview: rerun the projection per recommendation, run the Monte
   Carlo as a cached background job, show a fan chart, and run savings-rate
   sensitivity variants with `scenario.with(...)`.
7. AI tools on top of the engine output.

Before the FIRE-access rules (step 5) can work, the drawdown step needs to
know that retirement accounts can't be touched before 59½.

Later tiers:
- historical backtesting (`Simulator#run` already accepts any return
  sequence)
- withdrawal strategies, by extracting the drawdown step into strategy
  objects
- allocation drift
- Coast, Lean and Full FIRE milestones
- named scenarios (a family can already have several plans)
- Roth conversion and bracket filling, including Wisconsin
- pre-Medicare healthcare costs
- mortgage payoff versus investing
- a projected-versus-actual net-worth timeline

## Testing

- Engine: `test/models/retirement/`. Build scenarios by hand. Use zero returns
  and zero inflation for exact arithmetic, and zero volatility to check that
  Monte Carlo agrees with the deterministic path.
- Persistence: `test/models/retirement_plan_test.rb` and
  `test/models/retirement_plan/`, with fixtures in
  `test/fixtures/retirement_plans.yml` and `test/fixtures/retirement_plan/`.
- Pages: `test/controllers/retirement_plans_controller_test.rb` and
  `test/controllers/retirement_plans/`. Every nested page also needs a test
  showing that another family's plan or member returns 404.
