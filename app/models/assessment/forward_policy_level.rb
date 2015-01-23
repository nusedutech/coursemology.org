class Assessment::ForwardPolicyLevel < ActiveRecord::Base
	acts_as_paranoid
	attr_accessible :tag_id, :progression_threshold, :order, :wrong_threshold, :seconds_to_complete, :is_consecutive 

	validates_presence_of :tag_id, :progression_threshold, :tag_type

	belongs_to :forward_policy, class_name: "Assessment::ForwardPolicy"
	belongs_to :tag, class_name: "Tag", polymorphic: true
	has_many	:forward_groups, class_name: "Assessment::ForwardGroup", dependent: :destroy, foreign_key: :forward_policy_level_id

  def tag_is_tag_type?
    self.tag_type == "Tag"
  end

  def tag_is_topicconcept_type?
    self.tag_type == "Topicconcept"
  end

	#Get all questions linked to an assessment for a forward policy level
	#and permutate them
	def getAllQuestionsString(assessment)
		result = ""
		if assessment.is_a? Assessment
      qaLinks = []
      levelTaggableTags = self.tag.taggable_tags
      levelTaggableTags.each do |singleTaggableTag|
        qaLinks = qaLinks + assessment.question_assessments.where("question_assessments.question_id = ? ", singleTaggableTag.taggable_id)
      end

			arr = []
			qaLinks.each do |question|
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
      qaLinks = []
      levelTaggableTags = self.tag.taggable_tags
      levelTaggableTags.each do |singleTaggableTag|
        qaLinks = qaLinks + assessment.question_assessments.where("question_assessments.question_id = ? ", singleTaggableTag.taggable_id)
      end

      questions = []
      qaLinks.each do |qaLink|
        questions << qaLink.question
      end

		else
			questions = []
		end
	
		return questions
	end

	def getTag
		return self.tag
	end
end
