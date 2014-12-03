class CreateProgressionPolicies < ActiveRecord::Migration
  def up
		create_table  :assessment_progression_policies do |t|
			#For MTI
			t.integer 	:as_progression_policy_id
      t.string  	:as_progression_policy_type

			t.references	:policy_mission, index: true
			t.integer			:overall_seconds_to_complete, default: -1

      t.datetime    :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table		:assessment_progression_policies
  end
end
