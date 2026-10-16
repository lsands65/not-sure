class RetirementPlan::AccountLink < ApplicationRecord
  belongs_to :retirement_plan, inverse_of: :account_links
  belongs_to :account

  validates :account_id, uniqueness: { scope: :retirement_plan_id }
  validates :tax_bucket, inclusion: { in: Retirement::BUCKETS.map(&:to_s) }, allow_nil: true
  validate :account_is_family_asset

  # Sure's subtype gets most accounts right (401k → traditional, Roth IRA →
  # Roth), but a generic "Retirement" or "Other" subtype can't say which, so
  # the user's explicit tag wins.
  def effective_tax_bucket
    tax_bucket&.to_sym || self.class.inferred_bucket_for(account)
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
    # asset accounts.
    def account_is_family_asset
      return unless account && retirement_plan

      errors.add(:account, :invalid) unless account.family_id == retirement_plan.family_id && account.classification == "asset"
    end
end
