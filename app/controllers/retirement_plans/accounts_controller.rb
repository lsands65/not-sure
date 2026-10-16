# Which accounts fund the plan, and the tax bucket of each.
class RetirementPlans::AccountsController < RetirementPlans::BaseController
  def edit
    @accounts = candidate_accounts
    @links = @plan.account_links.index_by(&:account_id)
    @breadcrumbs = plan_breadcrumbs(t(".heading"))
  end

  def update
    submitted = params.fetch(:accounts, {})
    links = @plan.account_links.index_by(&:account_id)

    RetirementPlan.transaction do
      candidate_accounts.each do |account|
        choice = submitted[account.id] || {}
        link = links[account.id]

        if choice[:included] == "1"
          link ||= @plan.account_links.build(account:)
          link.update!(tax_bucket: choice[:tax_bucket].presence)
        else
          link&.destroy!
        end
      end
    end

    redirect_to retirement_plan_path(@plan), notice: t(".success")
  end

  private
    # Only accounts this user can see; links to anything else are left alone.
    def candidate_accounts
      Current.user.accessible_accounts.visible
             .where(accountable_type: RetirementPlan::AccountLink::FUNDING_ACCOUNT_TYPES)
             .includes(:accountable).order(:name)
    end
end
