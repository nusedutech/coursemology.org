class CreatePolicyMissions < ActiveRecord::Migration
  def up
		create_table  :assessment_policy_missions do |t|

      t.datetime    :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table		:assessment_policy_missions
  end
end
