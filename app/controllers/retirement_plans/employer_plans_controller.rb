class RetirementPlans::EmployerPlansController < RetirementPlans::BaseController
  before_action :set_member
  before_action :set_employer_plan

  def edit
    @breadcrumbs = plan_breadcrumbs(t(".heading", name: @member.name))
  end

  def update
    if @employer_plan.update(employer_plan_params)
      redirect_to retirement_plan_path(@plan), notice: t(".success")
    else
      @breadcrumbs = plan_breadcrumbs(t(".heading", name: @member.name))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @member.employer_plan&.destroy!
    redirect_to retirement_plan_path(@plan), notice: t(".success")
  end

  private
    def set_employer_plan
      @employer_plan = @member.employer_plan || @member.build_employer_plan
      @plan_accounts = Current.user.accessible_accounts.visible.where(accountable_type: "Investment").order(:name)
    end

    def employer_plan_params
      params.require(:employer_plan).permit(
        :employer_name, :plan_type, :account_id, :match_true_up,
        :match_rate_1_percent, :match_up_to_1_percent, :match_rate_2_percent, :match_up_to_2_percent,
        :nonelective_rate_percent, :expense_ratio_percent,
        :vesting_type, :vesting_years, :service_start_date,
        :roth_option, :after_tax_allowed, :in_plan_roth_conversion, :in_service_withdrawal,
        :accepts_rollovers, :hdhp_available
      ).tap do |permitted|
        %i[account_id vesting_type vesting_years service_start_date].each do |key|
          permitted[key] = permitted[key].presence if permitted.key?(key)
        end
        # Only accounts the user can see may be named as the plan's account.
        if permitted[:account_id] && !@plan_accounts.exists?(id: permitted[:account_id])
          permitted[:account_id] = nil
        end
      end
    end
end
