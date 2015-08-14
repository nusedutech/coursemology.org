class AddVotedAnswerIdToAssessmentGeneralAnswers < ActiveRecord::Migration
  def change
    add_column :assessment_general_answers, :voted_answer_id, :integer
  end
end
