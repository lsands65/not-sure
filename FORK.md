# About this fork

`lsands65/not-sure` is a fork of [we-promise/sure](https://github.com/we-promise/sure)
that adds **retirement planning**. It is meant to stay close to upstream: upstream's
work comes in regularly, and the fork's own code stays out of the way of
upstream merges.

Fork-only work is not meant to go upstream, so it does not need upstream's
preview gating or translations for every locale.

## Keeping up with upstream

```sh
git remote add upstream https://github.com/we-promise/sure.git   # once per clone
git fetch upstream
git checkout main
git merge upstream/main          # merge, never rebase: main is shared history
bin/rails test                   # then lint, per AGENTS.md
git push origin main
```

`.github/workflows/upstream-sync.yml` does the fetch every Monday and opens (or
refreshes) a PR from an `upstream-sync` branch that mirrors `upstream/main`.
Conflicts show on that PR. To resolve them, merge `upstream/main` into a local
branch off `main` as above.

For the workflow to open PRs, enable **Settings → Actions → General → Allow
GitHub Actions to create and approve pull requests**. PRs it opens are created
with `GITHUB_TOKEN`, so CI does not start on them by itself. Close and reopen
the PR, or run the merge locally, to get a CI run.

### Resolving common conflicts

- **`db/schema.rb`**: don't hand-merge. Take upstream's version, run
  `bin/rails db:migrate` against a scratch database so the fork's migrations are
  re-applied, and commit the regenerated file. Fork migrations use real timestamps,
  so they interleave with upstream's without renaming.
- **A file listed under "Upstream files the fork touches" below**: re-apply the
  fork's few lines on top of upstream's version.

## Rules for fork code

1. **New files over edited files.** Retirement code lives under its own names:

   | What | Where |
   | --- | --- |
   | Engine (pure Ruby, no ActiveRecord) | `app/models/retirement.rb`, `app/models/retirement/` |
   | Persistence | `app/models/retirement_plan.rb`, `app/models/retirement_plan/` |
   | Controllers | `app/controllers/retirement_plans_controller.rb`, `app/controllers/retirement_plans/` |
   | Views and helper | `app/views/retirement_plans/`, `app/helpers/retirement_plans_helper.rb` |
   | Routes | `config/routes/retirement.rb` |
   | Migrations | `db/migrate/*_retirement_*.rb` |
   | Locales | `config/locales/**/retirement_plan*/en.yml` |
   | Tests and fixtures | `test/models/retirement*`, `test/controllers/retirement_plans*`, `test/fixtures/retirement_plan*` |
   | Guide | `docs/llm-guides/retirement.md` |

2. **Don't add associations to upstream models.** Foreign keys into upstream
   tables (`families`, `accounts`) use `on_delete: :cascade` (or `:nullify`
   for an optional link), so `Family` and
   `Account` need no `has_many ... dependent:` line. Query with
   `RetirementPlan.for_family(Current.family)`.
3. **When an upstream file must change, keep it to a line or two** and list it
   below.
4. **Read upstream data through public methods** such as `Account#tax_treatment`,
   `Family#income_statement` and `Money#exchange_to`, never through their SQL
   internals, so upstream refactors break loudly in our tests rather than silently.

## Upstream files the fork touches

| File | Change | Why |
| --- | --- | --- |
| `AGENTS.md` | "Fork" section at the end | Points agents here |
| `db/schema.rb` | Generated retirement tables | Unavoidable; regenerate, never hand-merge |
| `config/routes.rb` | `draw :retirement` after `resource :plan` | Route mount; the routes live in `config/routes/retirement.rb` |
| `app/views/layouts/application.html.erb` | One "Retirement" entry in the nav item list, after `plan_nav_item` | Nav link |
