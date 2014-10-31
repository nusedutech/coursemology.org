class Assessment::ForwardGroup < ActiveRecord::Base
	require 'csv'

	acts_as_paranoid
	is_a :progression_group, as: :as_progression_group, class_name: "Assessment::ProgressionGroup"

	attr_accessible :submission_id, :uncompleted_questions, :completed_answers, :is_completed, :dued_at 
	attr_accessible :correct_amount_left, :wrong_amount_left, :is_consecutive 

	belongs_to :forward_policy_level, class_name: "Assessment::ForwardPolicyLevel"

	def getCorrespondingLevel
		Assessment::ForwardPolicyLevel.find(self.forward_policy_level_id)
	end


	def getTopQuestion(assessment)

		allQuestions = CSV.parse_line(self.uncompleted_questions)
		#We will only use line 0 so check line 0 only
		if allQuestions == nil || allQuestions.nil?
			policyLevel = self.getCorrespondingLevel
			newQuestions = policyLevel.getAllQuestionsString assessment
			self.uncompleted_questions = newQuestions
			self.save
			allQuestions = CSV.parse_line(newQuestions)
		end
		
		#remove one question
		questionId = allQuestions.shift
		todoQuestion = assessment.questions.find_by_id(questionId)
	end

	def removeTopQuestion
		allQuestions = CSV.parse_line(self.uncompleted_questions)
		allQuestions.shift
		self.uncompleted_questions = allQuestions.join(",")
		self.save
	end

	def recordAnswer(newAnswerId)
		if self.completed_answers.present?
			allAnswers = CSV.parse_line(self.completed_answers)
		else
			allAnswers = []
		end
		allAnswers.concat([newAnswerId])

		self.completed_answers = allAnswers.join(",")
		self.save
	end
end
