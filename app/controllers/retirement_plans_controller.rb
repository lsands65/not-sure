# Fork-only (see FORK.md and docs/llm-guides/retirement.md).
class RetirementPlansController < ApplicationController
  before_action :set_plan, only: %i[show edit update destroy]

  # One plan per household for now; several plans become named scenarios later.
  def index
    plan = plans.order(:created_at).first
    redirect_to plan ? retirement_plan_path(plan) : new_retirement_plan_path
  end

  def show
    @members = @plan.members.includes(:employer_plan, :paycheck).to_a
    @balances = @plan.balances_by_bucket
    @questions = @plan.missing_inputs
    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ @plan.name, nil ] ]
  end

  def new
    @plan = plans.new(name: t(".default_name"), currency: Current.family.primary_currency_code)
    build_member_slots
    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t(".heading"), nil ] ]
  end

  def create
    @plan = plans.new(plan_params)
    @plan.currency = Current.family.primary_currency_code

    RetirementPlan.transaction do
      @plan.save!
      RetirementPlan.suggested_accounts_from(Current.user.accessible_accounts).each do |account|
        @plan.account_links.create!(account:)
      end
    end

    redirect_to retirement_plan_path(@plan), notice: t(".success")
  rescue ActiveRecord::RecordInvalid
    build_member_slots
    render :new, status: :unprocessable_entity
  end

  def edit
    build_member_slots
    @breadcrumbs = plan_breadcrumbs(t(".heading"))
  end

  def update
    if @plan.update(plan_params)
      redirect_to retirement_plan_path(@plan), notice: t(".success")
    else
      build_member_slots
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plan.destroy!
    redirect_to root_path, notice: t(".success")
  end

  private
    def plans
      RetirementPlan.for_family(Current.family)
    end

    def set_plan
      @plan = plans.find(params[:id])
    end

    def plan_breadcrumbs(current)
      [ [ t("breadcrumbs.home"), root_path ], [ @plan.name, retirement_plan_path(@plan) ], [ current, nil ] ]
    end

    # The form always shows two person rows; a blank second row is ignored.
    def build_member_slots
      taken = @plan.members.map(&:position)
      (0...RetirementPlan::MAX_MEMBERS).each do |position|
        @plan.members.build(position:) unless taken.include?(position)
      end
      @plan.members.target.sort_by!(&:position)
    end

    def plan_params
      params.require(:retirement_plan).permit(
        :name, :filing_status, :state, :annual_spending_override, :notes,
        :inflation_rate_percent, :expected_return_percent, :return_volatility_percent,
        :withdrawal_rate_percent, :traditional_tax_rate_percent,
        members_attributes: %i[id position name birth_date retirement_age planning_age _destroy]
      ).tap do |permitted|
        permitted[:filing_status] = permitted[:filing_status].presence if permitted.key?(:filing_status)
        permitted[:state] = permitted[:state].presence if permitted.key?(:state)
        permitted[:annual_spending_override] = permitted[:annual_spending_override].presence if permitted.key?(:annual_spending_override)
      end
    end
end
