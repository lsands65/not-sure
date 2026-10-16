# Fork-only (see FORK.md). Build-order step 1: the inputs bank transactions
# can't supply — gross pay and pre-tax deductions, and the employer plan's
# rules. Yes/no plan features are nullable on purpose: nil means "not asked
# yet", which the planner turns into a question instead of a guess.
class AddEmployerPlansAndPaychecksToRetirement < ActiveRecord::Migration[8.1]
  def change
    add_column :retirement_plans, :filing_status, :string
    add_column :retirement_plans, :state, :string, limit: 2
    add_check_constraint :retirement_plans,
                         "filing_status IS NULL OR filing_status IN ('single','married_filing_jointly','married_filing_separately','head_of_household')",
                         name: "chk_retirement_plans_filing_status"

    create_table :retirement_plan_employer_plans, id: :uuid do |t|
      t.references :member, null: false, type: :uuid, index: { unique: true },
                   foreign_key: { to_table: :retirement_plan_members, on_delete: :cascade }
      t.references :account, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :employer_name
      t.string :plan_type, null: false, default: "401k"

      # Match formula as up to two tiers, e.g. 100% of the first 3% of pay
      # plus 50% of the next 2%: (1.0, 0.03), (0.5, 0.02). Tier 2 applies to
      # the pay above tier 1's cap. Plus any non-elective contribution.
      t.decimal :match_rate_1, precision: 6, scale: 4
      t.decimal :match_up_to_1, precision: 6, scale: 4
      t.decimal :match_rate_2, precision: 6, scale: 4
      t.decimal :match_up_to_2, precision: 6, scale: 4
      t.decimal :nonelective_rate, precision: 6, scale: 4
      t.boolean :match_true_up

      t.string :vesting_type
      t.integer :vesting_years
      t.date :service_start_date

      t.boolean :roth_option
      t.boolean :after_tax_allowed
      t.boolean :in_plan_roth_conversion
      t.boolean :in_service_withdrawal
      t.boolean :accepts_rollovers
      t.boolean :hdhp_available
      # Expense ratio of the fund you would actually use in the plan.
      t.decimal :expense_ratio, precision: 6, scale: 4

      t.timestamps
    end

    add_check_constraint :retirement_plan_employer_plans,
                         "plan_type IN ('401k','403b','457b','tsp','other')",
                         name: "chk_retirement_plan_employer_plans_plan_type"
    add_check_constraint :retirement_plan_employer_plans,
                         "vesting_type IS NULL OR vesting_type IN ('immediate','cliff','graded')",
                         name: "chk_retirement_plan_employer_plans_vesting_type"

    # One current paycheck per person, as printed on the stub (per period).
    create_table :retirement_plan_paychecks, id: :uuid do |t|
      t.references :member, null: false, type: :uuid, index: { unique: true },
                   foreign_key: { to_table: :retirement_plan_members, on_delete: :cascade }
      t.string :pay_frequency, null: false, default: "biweekly"
      t.decimal :gross_pay, precision: 19, scale: 4, null: false
      t.decimal :traditional_401k, precision: 19, scale: 4, null: false, default: 0
      t.decimal :roth_401k, precision: 19, scale: 4, null: false, default: 0
      t.decimal :after_tax_401k, precision: 19, scale: 4, null: false, default: 0
      t.decimal :hsa, precision: 19, scale: 4, null: false, default: 0
      t.decimal :health_premiums, precision: 19, scale: 4, null: false, default: 0
      t.decimal :other_pretax, precision: 19, scale: 4, null: false, default: 0
      # Annual, outside the per-period figures: irregular pay distorts averages.
      t.decimal :annual_bonus, precision: 19, scale: 4, null: false, default: 0
      t.decimal :employer_hsa_annual, precision: 19, scale: 4, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :retirement_plan_paychecks,
                         "pay_frequency IN ('weekly','biweekly','semimonthly','monthly')",
                         name: "chk_retirement_plan_paychecks_pay_frequency"
    add_check_constraint :retirement_plan_paychecks, "gross_pay > 0",
                         name: "chk_retirement_plan_paychecks_gross_positive"
  end
end
