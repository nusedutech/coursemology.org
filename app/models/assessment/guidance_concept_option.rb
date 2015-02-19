class Assessment::GuidanceConceptOption < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :enabled, :is_entry, :topicconcept_id
  validates_presence_of :topicconcept_id 

  belongs_to :topicconcept, class_name: Topicconcept, foreign_key: "topicconcept_id"
  has_many :concept_criteria, class_name: Assessment::GuidanceConceptCriterion, dependent: :destroy

  def self.update_attributes_with_new(topicconcept, attributes)
    concept_option = topicconcept.concept_option
    if concept_option.nil?
      concept_option = Assessment::GuidanceConceptOption.new
      concept_option.topicconcept_id = topicconcept.id
    end

    concept_option.update_attributes(attributes)
  end

  
end
