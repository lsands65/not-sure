# Fork-only (see FORK.md). Mounted from config/routes.rb with `draw :retirement`.
resources :retirement_plans do
  resource :accounts, only: %i[edit update], controller: "retirement_plans/accounts"

  resources :members, only: [] do
    resource :employer_plan, only: %i[edit update destroy], controller: "retirement_plans/employer_plans"
    resource :paycheck, only: %i[edit update destroy], controller: "retirement_plans/paychecks"
  end
end
