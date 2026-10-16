# Fork-only (see FORK.md).
module RetirementPlansHelper
  def retirement_percent(fraction, precision: 1)
    return t("retirement_plans.shared.unknown") if fraction.nil?

    number_to_percentage(fraction.to_d * 100, precision:, strip_insignificant_zeros: true)
  end

  def retirement_bucket_label(bucket)
    t("retirement_plans.shared.buckets.#{bucket}")
  end

  # Tri-state select for yes/no plan features: blank means "not sure yet".
  def retirement_yes_no_options
    [ [ t("retirement_plans.shared.yes"), "true" ], [ t("retirement_plans.shared.no"), "false" ] ]
  end

  # Turns a RetirementPlan#missing_inputs pair into the question to ask and
  # the page that answers it.
  def retirement_question(plan, subject, attribute)
    case subject
    when RetirementPlan
      { text: t("retirement_plans.questions.plan.#{attribute}"), path: edit_retirement_plan_path(plan) }
    when RetirementPlan::Member
      path = attribute == :paycheck ? edit_retirement_plan_member_paycheck_path(plan, subject) : edit_retirement_plan_member_employer_plan_path(plan, subject)
      { text: t("retirement_plans.questions.member.#{attribute}", name: subject.name), path: }
    when RetirementPlan::EmployerPlan
      {
        text: t("retirement_plans.questions.employer_plan.#{attribute}", name: subject.member.name),
        path: edit_retirement_plan_member_employer_plan_path(plan, subject.member)
      }
    when RetirementPlan::AccountLink
      { text: t("retirement_plans.questions.account_link.tax_bucket", account: subject.account.name), path: edit_retirement_plan_accounts_path(plan) }
    end
  end
end
