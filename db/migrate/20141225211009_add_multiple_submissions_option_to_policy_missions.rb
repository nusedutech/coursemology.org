class AddMultipleSubmissionsOptionToPolicyMissions < ActiveRecord::Migration
  def change
    add_column :assessment_policy_missions, :multiple_submissions, :boolean, default: false
  end
end
