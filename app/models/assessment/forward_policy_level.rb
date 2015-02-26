class Assessment::ForwardPolicyLevel < ActiveRecord::Base
  acts_as_paranoid
  attr_accessible :forward_policy_theme_id, :progression_threshold, :order, :wrong_threshold, :seconds_to_complete, :is_consecutive 

  validates_presence_of :forward_policy_theme_id, :progression_threshold, :forward_policy_theme_type

  belongs_to :forward_policy, class_name: "Assessment::ForwardPolicy"
  belongs_to :forward_policy_theme, polymorphic: true

  has_many	:forward_groups, class_name: "Assessment::ForwardGroup", dependent: :destroy, foreign_key: :forward_policy_level_id

  #Get all questions linked to an assessment for a forward policy level
  #and permutate them
  def getAllQuestionsString(assessment)
	result = ""

	if assessment.is_a? Assessment
      qaLinks = []
      levelTaggableTags = self.forward_policy_theme.taggable_tags
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
      levelTaggableTags = self.forward_policy_theme.taggable_tags
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
	return self.forward_policy_theme
  end
end
