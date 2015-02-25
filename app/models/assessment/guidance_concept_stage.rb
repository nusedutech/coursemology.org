class Assessment::GuidanceConceptStage < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :disabled_topicconcept_id, :total_wrong, :total_right, :assessment_submission_id, :topicconcept_id
  validates_presence_of :assessment_submission_id, :topicconcept_id

  belongs_to :topicconcept, class_name: Topicconcept, foreign_key: "topicconcept_id"
  belongs_to :submission, class_name: Assessment::Submission, foreign_key: "assessment_submission_id"
  
  has_many :concept_edge_stages, class_name: Assessment::GuidanceConceptEdgeStage, dependent: :destroy
 
  
end
