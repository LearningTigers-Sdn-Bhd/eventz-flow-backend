class AddPlanObjectToPassBundles < ActiveRecord::Migration[8.0]
  def change
    add_reference :pass_bundles, :plan_object, foreign_key: true, index: true
  end
end
