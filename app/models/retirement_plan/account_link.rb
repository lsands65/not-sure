class RetirementPlan::AccountLink < ApplicationRecord
  belongs_to :retirement_plan, inverse_of: :account_links
  belongs_to :account

  GENERIC_SUBTYPES = [ nil, "", "retirement", "pension", "other" ].freeze
  # Accounts whose balance can be spent in retirement; a house or a car can't.
  FUNDING_ACCOUNT_TYPES = %w[Depository Investment Crypto].freeze

  validates :account_id, uniqueness: { scope: :retirement_plan_id }
  validates :tax_bucket, inclusion: { in: Retirement::BUCKETS.map(&:to_s) }, allow_nil: true
  validate :account_is_family_asset

  # Sure's subtype gets most accounts right (401k → traditional, Roth IRA →
  # Roth), but a generic "Retirement" or "Other" subtype can't say which, so
  # the user's explicit tag wins.
  def effective_tax_bucket
    tax_bucket&.to_sym || self.class.inferred_bucket_for(account)
  end

  # The subtype doesn't say which bucket (a generic "Retirement" account, or
  # no subtype at all), so the inferred bucket is a guess worth confirming.
  def tax_bucket_ambiguous?
    tax_bucket.nil? && account.accountable_type == "Investment" && account.subtype.in?(GENERIC_SUBTYPES)
  end

  class << self
    def inferred_bucket_for(account)
      return :hsa if account.subtype == "hsa"

      case account.tax_treatment
      when :tax_deferred then :traditional
      when :tax_exempt, :tax_advantaged then :roth
      else :taxable
      end
    end
  end

  private
    # Tenancy guard: a plan may only read balances from its own family's
    # funding accounts.
    def account_is_family_asset
      return unless account && retirement_plan

      valid = account.family_id == retirement_plan.family_id && account.accountable_type.in?(FUNDING_ACCOUNT_TYPES)
      errors.add(:account, :invalid) unless valid
    end
end
