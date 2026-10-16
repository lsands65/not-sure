# One member's current paycheck, entered as printed on the pay stub. Bank
# deposits only show take-home pay, so pre-tax 401(k) and HSA savings never
# appear in Sure's transactions; this is where they come from.
class RetirementPlan::Paycheck < ApplicationRecord
  PERIODS_PER_YEAR = { "weekly" => 52, "biweekly" => 26, "semimonthly" => 24, "monthly" => 12 }.freeze
  DEDUCTIONS = %i[traditional_401k roth_401k after_tax_401k hsa health_premiums other_pretax].freeze

  belongs_to :member, class_name: "RetirementPlan::Member", inverse_of: :paycheck

  validates :pay_frequency, inclusion: { in: PERIODS_PER_YEAR.keys }
  validates :gross_pay, numericality: { greater_than: 0 }
  validates(*DEDUCTIONS, :annual_bonus, :employer_hsa_annual, numericality: { greater_than_or_equal_to: 0 })
  validate :deductions_fit_in_gross_pay

  def periods_per_year
    PERIODS_PER_YEAR.fetch(pay_frequency)
  end

  def annual(attribute)
    public_send(attribute).to_d * periods_per_year
  end

  def annual_gross
    annual(:gross_pay) + annual_bonus
  end

  # Employee 401(k) deferrals (traditional + Roth) as a fraction of base pay.
  # The bonus is left out: whether it is deferred varies by plan.
  def deferral_rate
    (traditional_401k + roth_401k) / gross_pay
  end

  def annual_employee_deferrals
    annual(:traditional_401k) + annual(:roth_401k)
  end

  # What payroll saves on the member's behalf in a year, before anything
  # reaches a bank account.
  def annual_payroll_savings
    annual_employee_deferrals + annual(:after_tax_401k) + annual(:hsa) + employer_hsa_annual
  end

  def annual_pretax_deductions
    annual(:traditional_401k) + annual(:hsa) + annual(:health_premiums) + annual(:other_pretax)
  end

  private
    def deductions_fit_in_gross_pay
      return if gross_pay.blank?

      total = DEDUCTIONS.sum { |attribute| public_send(attribute).to_d }
      errors.add(:base, :deductions_exceed_gross) if total > gross_pay
    end
end
