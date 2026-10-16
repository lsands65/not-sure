# The employer retirement plan behind one member's paycheck. It drives more
# recommendations than anything else (match first, Roth vs traditional, mega
# backdoor, rollovers), so unknown yes/no answers stay nil and surface through
# #missing_inputs as questions rather than being guessed.
class RetirementPlan::EmployerPlan < ApplicationRecord
  include RetirementPlan::PercentAttributes

  PLAN_TYPES = %w[401k 403b 457b tsp other].freeze
  VESTING_TYPES = %w[immediate cliff graded].freeze

  # Asked about until answered; order is the order the form shows them.
  QUESTIONS = %i[
    match_rate_1 match_up_to_1 match_true_up vesting_type roth_option
    after_tax_allowed in_plan_roth_conversion in_service_withdrawal
    accepts_rollovers hdhp_available expense_ratio
  ].freeze

  belongs_to :member, class_name: "RetirementPlan::Member", inverse_of: :employer_plan
  belongs_to :account, optional: true

  percent_attribute :match_rate_1, :match_up_to_1, :match_rate_2, :match_up_to_2, :nonelective_rate, :expense_ratio

  validates :plan_type, inclusion: { in: PLAN_TYPES }
  validates :vesting_type, inclusion: { in: VESTING_TYPES }, allow_nil: true
  validates :match_rate_1, :match_rate_2, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }, allow_nil: true
  validates :match_up_to_1, :match_up_to_2, :nonelective_rate, :expense_ratio,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :vesting_years, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :tiers_are_complete
  validate :account_belongs_to_family

  # Fraction of pay the employer adds for a given employee deferral rate.
  # Nil while the formula is unknown.
  def employer_rate_for(deferral_rate)
    return nil unless match_formula_known?

    deferral = deferral_rate.to_d
    tier_1 = [ deferral, match_up_to_1 ].min * match_rate_1
    above_tier_1 = [ deferral - match_up_to_1, 0 ].max
    tier_2 = match_rate_2 ? [ above_tier_1, match_up_to_2 ].min * match_rate_2 : 0

    tier_1 + tier_2 + nonelective_rate.to_d
  end

  # The deferral rate that captures every matched dollar.
  def full_match_deferral_rate
    return nil unless match_formula_known?

    match_up_to_1 + match_up_to_2.to_d
  end

  def match_formula_known?
    match_rate_1.present? && match_up_to_1.present?
  end

  # Share of employer money that is yours if you left on `on`. Graded vesting
  # is modelled as linear over vesting_years; plans that vest 20% a year from
  # year two differ slightly. Nil when the schedule or start date is unknown.
  def vested_fraction(on: Date.current)
    return nil if vesting_type.nil?
    return 1.to_d if vesting_type == "immediate"
    return nil if vesting_years.nil? || service_start_date.nil?

    years = ((on - service_start_date) / 365.25).floor
    if vesting_type == "cliff"
      years >= vesting_years ? 1.to_d : 0.to_d
    else
      [ years.to_d / vesting_years, 1 ].min
    end
  end

  def missing_inputs
    missing = QUESTIONS.select { |attribute| public_send(attribute).nil? }
    if vesting_type.in?(%w[cliff graded])
      missing << :vesting_years if vesting_years.nil?
      missing << :service_start_date if service_start_date.nil?
    end
    missing
  end

  private
    def tiers_are_complete
      errors.add(:match_up_to_1, :blank) if match_rate_1.present? && match_up_to_1.nil?
      errors.add(:match_rate_1, :blank) if match_up_to_1.present? && match_rate_1.nil?
      errors.add(:match_up_to_2, :blank) if match_rate_2.present? && match_up_to_2.nil?
      errors.add(:match_rate_2, :blank) if match_up_to_2.present? && match_rate_2.nil?
      errors.add(:match_rate_2, :requires_first_tier) if match_rate_2.present? && match_rate_1.nil?
    end

    def account_belongs_to_family
      return unless account && member

      errors.add(:account, :invalid) unless account.family_id == member.retirement_plan.family_id
    end
end
