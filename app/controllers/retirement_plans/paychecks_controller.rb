class RetirementPlans::PaychecksController < RetirementPlans::BaseController
  before_action :set_member
  before_action :set_paycheck

  def edit
    @breadcrumbs = plan_breadcrumbs(t(".heading", name: @member.name))
  end

  def update
    if @paycheck.update(paycheck_params)
      redirect_to retirement_plan_path(@plan), notice: t(".success")
    else
      @breadcrumbs = plan_breadcrumbs(t(".heading", name: @member.name))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @member.paycheck&.destroy!
    redirect_to retirement_plan_path(@plan), notice: t(".success")
  end

  private
    def set_paycheck
      @paycheck = @member.paycheck || @member.build_paycheck
    end

    def paycheck_params
      params.require(:paycheck).permit(
        :pay_frequency, :gross_pay, *RetirementPlan::Paycheck::DEDUCTIONS, :annual_bonus, :employer_hsa_annual
      ).tap do |permitted|
        (RetirementPlan::Paycheck::DEDUCTIONS + %i[annual_bonus employer_hsa_annual]).each do |key|
          permitted[key] = permitted[key].presence || 0 if permitted.key?(key)
        end
      end
    end
end
