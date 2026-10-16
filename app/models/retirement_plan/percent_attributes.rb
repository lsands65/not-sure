# Rates are stored as fractions (0.07) but typed as percentages (7). For each
# named attribute this adds `<name>_percent` readers and writers for forms.
module RetirementPlan::PercentAttributes
  extend ActiveSupport::Concern

  class_methods do
    def percent_attribute(*names)
      names.each do |name|
        define_method("#{name}_percent") do
          value = public_send(name)
          value && (value * 100).round(4).to_s("F").delete_suffix(".0")
        end

        define_method("#{name}_percent=") do |percent|
          public_send("#{name}=", percent.blank? ? nil : percent.to_d / 100)
        end
      end
    end
  end
end
