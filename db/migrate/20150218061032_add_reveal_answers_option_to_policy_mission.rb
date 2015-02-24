class AddRevealAnswersOptionToPolicyMission < ActiveRecord::Migration
  def change
    add_column :assessment_policy_missions, :reveal_answers, :boolean, default: false
  end
end
