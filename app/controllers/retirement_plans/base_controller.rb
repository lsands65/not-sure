# Shared lookup for pages nested under a retirement plan. Everything is found
# through the current family's plans, so another family's ids 404.
class RetirementPlans::BaseController < ApplicationController
  before_action :set_plan

  private
    def set_plan
      @plan = RetirementPlan.for_family(Current.family).find(params[:retirement_plan_id])
    end

    def set_member
      @member = @plan.members.find(params[:member_id])
    end

    def plan_breadcrumbs(current)
      [ [ t("breadcrumbs.home"), root_path ], [ @plan.name, retirement_plan_path(@plan) ], [ current, nil ] ]
    end
end
