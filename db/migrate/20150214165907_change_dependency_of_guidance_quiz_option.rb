class ChangeDependencyOfGuidanceQuizOption < ActiveRecord::Migration
  def change
		add_column :assessment_guidance_concept_options, :concept_edge_id, :integer
    remove_column :assessment_guidance_concept_options, :topicconcept_id
    remove_column :assessment_guidance_concept_options, :assessment_guidance_quizzes_id
  end
end
