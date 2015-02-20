class Assessment::GuidanceQuizzesController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :guidance_quiz, class: "Assessment::GuidanceQuiz", through: :course
  before_filter :load_general_course_data, only: [:access_denied]


  #Only one guidance assessment per course, hence 
  #we use a collection method to constantly access it
  def set_enabled
    enabled = params[:enable]

    if enabled == "true"
		  Assessment::GuidanceQuiz.enable(@course)
    else
      Assessment::GuidanceQuiz.disable(@course)
    end
    
    respond_to do |format| 
      format.json { render json: { result: true}}
    end
  end

  def set_concept_edge_relation
    concept_edge = @course.concept_edges.where(id: params["concept_edge_id"]).first
    if !concept_edge.nil?
      result = ""
      #Initialise / create concept option (if not created before)
      if params[:enabled] == "true"
		    Assessment::GuidanceConceptEdgeOption.enable(concept_edge)
        result = "Concept-edge is enabled - with the following criteria:"
      else
        Assessment::GuidanceConceptEdgeOption.disable(concept_edge)
        result = "Concept-edge is disabled - with the following criteria:"
      end
      #Reload Concept Edge to get the child relation
      concept_edge = @course.concept_edges.where(id: params["concept_edge_id"]).first
      concept_edge_option = concept_edge.concept_edge_option
      if params.has_key?(:correct_threshold)
        result += "\n" + set_concept_edge_correct_threshold(concept_edge_option, params[:correct_threshold])
      end

      respond_to do |format| 
        format.json { render json: { result: result}}
      end
    else
      respond_to do |format| 
        format.json { render json: { result: "Concept-edge was not found"}}
      end
    end
  end

  def get_concept_edge_relation
    concept_edge = @course.concept_edges.where(id: params["concept_edge_id"]).first
    if !concept_edge.nil?
      result = {
                 concept_edge_id: concept_edge.id
               }
      concept_edge_option = concept_edge.concept_edge_option
      if !concept_edge_option.nil?
        result[:enabled] = concept_edge_option.enabled
        result[:criteria] = compress_concept_edge_criteria_from concept_edge_option
      else
        result[:enabled] = false
        result[:criteria] = default_concept_edge_criteria_values
      end

      respond_to do |format| 
        format.json { render json: result}
      end
    else
      raise "Concept edge id is invalid"
    end
  end

  def set_concept_criteria
    concept = @course.topicconcepts.concepts.where(id: params["concept_id"]).first
    if !concept.nil?
      attributes = { 
        enabled: (params.has_key?(:enabled) and params[:enabled] == "true"),
        is_entry: (params.has_key?(:is_entry) and params[:is_entry] == "true")
      }
      #Initialise / create concept option (if not created before)
      concept_option = Assessment::GuidanceConceptOption.update_attributes_with_new concept, attributes
      result = "Concept Options updated"

      if params.has_key?(:wrong_threshold)
        result += "\n" + set_concept_wrong_threshold(concept_option, params[:wrong_threshold])
      end

      respond_to do |format| 
        format.json { render json: { result: result}}
      end
    else
      respond_to do |format| 
        format.json { render json: { result: "Concept-edge was not found"}}
      end
    end
  end

  def get_concept_criteria
    concept = @course.topicconcepts.concepts.where(id: params["concept_id"]).first
    if !concept.nil?
      result = {
                 concept_id: concept.id
               }
      concept_option = concept.concept_option
      if !concept_option.nil?
        result[:enabled] = concept_option.enabled
        result[:is_entry] = concept_option.is_entry
        result[:criteria] = compress_concept_criteria_from concept_option
      #Default Values for display purposes
      else
        result[:enabled] = false
        result[:is_entry] = false
        result[:criteria] = default_concept_criteria_values
      end

      respond_to do |format| 
        format.json { render json: result}
      end
    else
      raise "Concept id is invalid"
    end
  end

  #Retrieve relation / passing criteria from a single edge based option
  def compress_concept_edge_criteria_from concept_edge_option
    result = default_concept_edge_criteria_values

    #Retrieve criteria info
    concept_edge_option.concept_edge_criteria.each do |criterion|
      case (criterion.specific.is_type)
        when "correct_threshold"
          result[:correct_threshold] = criterion.specific.threshold
      end
    end
    result
  end

  #Initial Default values - future pref values can be set here
  def default_concept_edge_criteria_values
    {
      correct_threshold: 0
    }
  end

  #Retrieve concept / failing criteria from a single concept based option
  def compress_concept_criteria_from concept_option
    result = default_concept_criteria_values

    #Retrieve criteria info
    concept_option.concept_criteria.each do |criterion|
      case (criterion.specific.is_type)
        when "wrong_threshold"
          result[:wrong_threshold] = criterion.specific.threshold
      end
    end
    result
  end

  #Initial Default values - future pref values can be set here
  def default_concept_criteria_values
    {
      wrong_threshold: 0
    }
  end

  def set_concept_edge_correct_threshold(concept_edge_option, correct_threshold_amt)

    result = "\n[ Correct Threshold ]"
    correct_threshold_single = concept_edge_option.concept_edge_criteria.correct_threshold_subcriteria.first

    if !correct_threshold_single.nil?
      correct_threshold_criterion = correct_threshold_single.specific
    else
      correct_threshold_criterion = Assessment::CorrectThreshold.new
      correct_threshold_criterion.guidance_concept_edge_option = concept_edge_option
    end

    #Match integers only
    if integer_check correct_threshold_amt
      amt = correct_threshold_amt.to_i
      if amt > 0
        correct_threshold_criterion.threshold = amt
        correct_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        correct_threshold_criterion.destroy
        result += "\n - " + "0 / Negative integer entered. Criteria deleted."
      end
    else
      result += "\n - " + "Non-integer entered. No changes made."
    end
    result
  end

  def set_concept_wrong_threshold(concept_option, wrong_threshold_amt)

    result = "\n[ Wrong Threshold ]"
    wrong_threshold_single = concept_option.concept_criteria.wrong_threshold_subcriteria.first

    if !wrong_threshold_single.nil?
      wrong_threshold_criterion = wrong_threshold_single.specific
    else
      wrong_threshold_criterion = Assessment::WrongThreshold.new
      wrong_threshold_criterion.guidance_concept_option = concept_option
    end

    #Match integers only
    if integer_check wrong_threshold_amt
      amt = wrong_threshold_amt.to_i
      if amt > 0
        wrong_threshold_criterion.threshold = amt
        wrong_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        wrong_threshold_criterion.destroy
        result += "\n - " + "0 / Negative integer entered. Criteria deleted."
      end
    else
      result += "\n - " + "Non-integer entered. No changes made."
    end
    result
  end

  def integer_check unit
    unit =~ /^(-|\+)?(\d+)$/
  end

  def access_denied

  end
end
