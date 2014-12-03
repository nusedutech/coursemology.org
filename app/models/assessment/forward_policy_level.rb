class Assessment::ForwardPolicyLevel < ActiveRecord::Base
	acts_as_paranoid
	attr_accessible :tag_id, :progression_threshold, :order, :wrong_threshold, :seconds_to_complete, :is_consecutive 

	validates_presence_of :tag_id, :progression_threshold

	belongs_to :forward_policy, class_name: "Assessment::ForwardPolicy"
	belongs_to :tag, class_name: "Tag"
	has_many	:forward_groups, class_name: "Assessment::ForwardGroup"


	#Get all questions linked to an assessment for a forward policy level
	#and permutate them
	def getAllQuestionsString(assessment)
		result = ""
		if assessment.is_a? Assessment
			questions = QuestionAssessment.find_by_sql(["SELECT * FROM question_assessments, taggable_tags WHERE taggable_tags.taggable_id = question_assessments.question_id and question_assessments.assessment_id = ? and taggable_tags.tag_id = ?", assessment.id, self.tag_id ])

			arr = []
			questions.each do |question|
				arr.push(question.question_id)
			end
			#permutate questions
			arrNeo = arr.shuffle
			#CSV string save
			result = arrNeo.join(",")
		end

		return result
	end

	def getAllRelatedQuestions(assessment)
		if assessment.is_a? Assessment
			questions = Assessment::Question.find_by_sql(["SELECT * FROM assessment_questions, question_assessments, taggable_tags WHERE taggable_tags.taggable_id = question_assessments.question_id and assessment_questions.id = question_assessments.question_id and question_assessments.assessment_id = ? and taggable_tags.tag_id = ?", assessment.id, self.tag_id ])
		else
			questions = []
		end
	
		return questions
	end

	def getTag
		Tag.find(self.tag_id)
	end
end
