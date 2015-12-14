class Assessment::GuidanceConceptOption < ActiveRecord::Base
  acts_as_paranoid
  acts_as_duplicable

  attr_accessible :enabled, :is_entry, :topicconcept_id
  validates_presence_of :topicconcept_id

  belongs_to :topicconcept, class_name: Topicconcept, foreign_key: "topicconcept_id"
  has_many :concept_criteria, class_name: Assessment::GuidanceConceptCriterion, dependent: :destroy

  amoeba do
    include_field [:concept_criteria]
  end

  def self.update_attributes_with_new (topicconcept, attributes)
    concept_option = topicconcept.concept_option
    if concept_option.nil?
      concept_option = Assessment::GuidanceConceptOption.new
      concept_option.topicconcept_id = topicconcept.id
      concept_option.save
    end

    concept_option.update_attributes(attributes)
    concept_option
  end

  def self.can_enter_with concept
    concept_option = concept.concept_option
    if concept_option.nil?
      return nil
    else
      return concept_option.can_enter?
    end
  end

  def self.is_enabled_with concept
    concept_option = concept.concept_option
    if concept_option.nil?
      return nil
    else
      return concept_option.is_enabled?
    end
  end

  #Check if the related concept can be entered
  def can_enter?
    self.enabled and self.is_entry
  end

  def is_enabled?
    self.enabled
  end
end
