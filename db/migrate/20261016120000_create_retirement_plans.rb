# Fork-only (see FORK.md). Every foreign key into an upstream table cascades,
# so upstream models (Family, Account) need no `has_many ... dependent:` line.
class CreateRetirementPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :retirement_plans, id: :uuid do |t|
      t.references :family, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :name, null: false
      t.string :currency, null: false
      # nil = derive from the family's trailing 12 months of spending.
      t.decimal :annual_spending_override, precision: 19, scale: 4
      t.decimal :inflation_rate, precision: 6, scale: 4, null: false, default: 0.025
      t.decimal :expected_return, precision: 6, scale: 4, null: false, default: 0.07
      t.decimal :return_volatility, precision: 6, scale: 4, null: false, default: 0.15
      t.decimal :withdrawal_rate, precision: 6, scale: 4, null: false, default: 0.04
      t.decimal :traditional_tax_rate, precision: 6, scale: 4, null: false, default: 0.15
      t.text :notes

      t.timestamps
    end

    add_check_constraint :retirement_plans, "annual_spending_override >= 0", name: "chk_retirement_plans_spending_non_negative"
    add_check_constraint :retirement_plans, "return_volatility >= 0", name: "chk_retirement_plans_volatility_non_negative"
    add_check_constraint :retirement_plans, "withdrawal_rate > 0 AND withdrawal_rate < 1",
                         name: "chk_retirement_plans_withdrawal_rate_range"
    add_check_constraint :retirement_plans,
                         "traditional_tax_rate >= 0 AND traditional_tax_rate < 1",
                         name: "chk_retirement_plans_tax_rate_range"

    # At most two members per plan, enforced by position.
    create_table :retirement_plan_members, id: :uuid do |t|
      t.references :retirement_plan, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.integer :position, null: false, default: 0
      t.string :name, null: false
      t.date :birth_date, null: false
      t.integer :retirement_age, null: false
      t.integer :planning_age, null: false, default: 95

      t.timestamps
    end

    add_index :retirement_plan_members, [ :retirement_plan_id, :position ], unique: true
    add_check_constraint :retirement_plan_members, "position IN (0, 1)", name: "chk_retirement_plan_members_position"
    add_check_constraint :retirement_plan_members,
                         "retirement_age > 0 AND planning_age > retirement_age AND planning_age <= 120",
                         name: "chk_retirement_plan_members_ages"

    create_table :retirement_plan_contributions, id: :uuid do |t|
      t.references :retirement_plan, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :member, null: false, type: :uuid,
                   foreign_key: { to_table: :retirement_plan_members, on_delete: :cascade }
      t.string :bucket, null: false
      t.decimal :annual_amount, precision: 19, scale: 4, null: false

      t.timestamps
    end

    add_check_constraint :retirement_plan_contributions,
                         "bucket IN ('taxable','traditional','roth','hsa')",
                         name: "chk_retirement_plan_contributions_bucket"
    add_check_constraint :retirement_plan_contributions, "annual_amount >= 0",
                         name: "chk_retirement_plan_contributions_amount_non_negative"

    create_table :retirement_plan_income_streams, id: :uuid do |t|
      t.references :retirement_plan, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :member, null: false, type: :uuid,
                   foreign_key: { to_table: :retirement_plan_members, on_delete: :cascade }
      t.string :kind, null: false
      t.string :name
      t.decimal :annual_amount, precision: 19, scale: 4, null: false
      t.integer :start_age, null: false
      t.integer :end_age
      t.boolean :inflation_adjusted, null: false, default: true

      t.timestamps
    end

    add_check_constraint :retirement_plan_income_streams,
                         "kind IN ('social_security','pension','annuity','employment','rental','other')",
                         name: "chk_retirement_plan_income_streams_kind"
    add_check_constraint :retirement_plan_income_streams, "annual_amount >= 0",
                         name: "chk_retirement_plan_income_streams_amount_non_negative"
    add_check_constraint :retirement_plan_income_streams, "end_age IS NULL OR end_age >= start_age",
                         name: "chk_retirement_plan_income_streams_age_range"

    create_table :retirement_plan_account_links, id: :uuid do |t|
      t.references :retirement_plan, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      # nil = infer from the account's Sure subtype.
      t.string :tax_bucket

      t.timestamps
    end

    add_check_constraint :retirement_plan_account_links,
                         "tax_bucket IS NULL OR tax_bucket IN ('taxable','traditional','roth','hsa')",
                         name: "chk_retirement_plan_account_links_tax_bucket"
    add_index :retirement_plan_account_links, [ :retirement_plan_id, :account_id ],
              unique: true, name: "index_retirement_plan_account_links_uniqueness"
  end
end
