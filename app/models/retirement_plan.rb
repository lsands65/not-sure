# A household's retirement plan: who retires when, what they will spend, what
# they save, what income arrives later, and which accounts fund it.
#
# Fork-only (see FORK.md). Family has no `has_many :retirement_plans` on
# purpose — query through `RetirementPlan.for_family` so upstream's family.rb
# stays untouched; the family foreign key cascades on delete.
#
# The projection math lives in Retirement::* POROs, fed by #scenario.
class RetirementPlan < ApplicationRecord
  include Monetizable

  MAX_MEMBERS = 2

  belongs_to :family

  has_many :members, -> { order(:position) }, class_name: "RetirementPlan::Member",
           inverse_of: :retirement_plan, dependent: :destroy
  has_many :contributions, class_name: "RetirementPlan::Contribution",
           inverse_of: :retirement_plan, dependent: :destroy
  has_many :income_streams, class_name: "RetirementPlan::IncomeStream",
           inverse_of: :retirement_plan, dependent: :destroy
  has_many :account_links, class_name: "RetirementPlan::AccountLink",
           inverse_of: :retirement_plan, dependent: :destroy
  has_many :linked_accounts, through: :account_links, source: :account

  accepts_nested_attributes_for :members, :contributions, :income_streams, allow_destroy: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :currency, presence: true
  validates :annual_spending_override, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :inflation_rate, :expected_return, numericality: { greater_than: -1, less_than: 1 }
  validates :return_volatility, numericality: { greater_than_or_equal_to: 0, less_than: 1 }
  validates :withdrawal_rate, numericality: { greater_than: 0, less_than: 1 }
  validates :traditional_tax_rate, numericality: { greater_than_or_equal_to: 0, less_than: 1 }
  validate :one_or_two_members

  scope :for_family, ->(family) { where(family:) }

  class << self
    # Accounts a new plan links by default: visible, tax-advantaged assets.
    def suggested_accounts_for(family)
      family.accounts.visible.assets.includes(:accountable).select(&:tax_advantaged?)
    end
  end

  # What the household spends per year, in today's money: the user's override
  # if set, otherwise the trailing 12 months of actual spending.
  def annual_spending
    annual_spending_override || trailing_annual_spending
  end

  def annual_spending_money
    Money.new(annual_spending, currency)
  end

  # First cut of the Tier 1 baseline: total expenses over the last 12 months,
  # converted to the plan currency. The essential/discretionary split and
  # one-off filtering refine this; see docs/llm-guides/retirement.md.
  def trailing_annual_spending
    @trailing_annual_spending ||= begin
      range = (Date.current - 12.months)..Date.current
      family.income_statement(user: nil).totals(date_range: range).expense_money.exchange_to(currency).amount
    rescue Money::ConversionError
      0.to_d
    end
  end

  # The portfolio that sustains `annual_spending` at `withdrawal_rate`, before
  # counting Social Security or pensions (the Monte Carlo accounts for those).
  def target_portfolio_money
    Money.new(annual_spending / withdrawal_rate, currency)
  end

  def balances_by_bucket
    Retirement::BUCKETS.index_with { 0.to_d }.tap do |totals|
      account_links.includes(account: :accountable).each do |link|
        totals[link.effective_tax_bucket] += link.account.balance_money.exchange_to(currency).amount
      rescue Money::ConversionError
        # An account with no exchange rate is left out rather than counted at
        # the wrong value; the UI should surface it once one exists.
        next
      end
    end
  end

  def scenario(start_year: Date.current.year)
    ordered_members = members.to_a
    index_of = ordered_members.each_with_index.to_h { |member, index| [ member.id, index ] }

    Retirement::Scenario.new(
      start_year:,
      members: ordered_members.map(&:to_engine),
      balances: balances_by_bucket.transform_values(&:to_f),
      contributions: contributions.map { |c| c.to_engine(index_of.fetch(c.member_id)) },
      income_streams: income_streams.map { |s| s.to_engine(index_of.fetch(s.member_id)) },
      annual_spending: annual_spending.to_f,
      inflation_rate: inflation_rate.to_f,
      expected_return: expected_return.to_f,
      return_volatility: return_volatility.to_f,
      traditional_tax_rate: traditional_tax_rate.to_f
    )
  end

  def projection(**options)
    Retirement::Projection.new(scenario, **options)
  end

  private
    def one_or_two_members
      count = members.reject(&:marked_for_destruction?).size
      return if count.between?(1, MAX_MEMBERS)

      errors.add(:members, :count, count: MAX_MEMBERS)
    end
end
