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

  def set_concept_relation
    concept_edge = @course.concept_edges.where(id: params["concept_edge_id"]).first
    if !concept_edge.nil?
      result = ""
      #Initialise / create concept option (if not created before)
      if params[:enabled] == "true"
		    Assessment::GuidanceConceptOption.enable(concept_edge)
        result = "Concept-edge is enabled - with the following criteria:"
      else
        Assessment::GuidanceConceptOption.disable(concept_edge)
        result = "Concept-edge is disabled - with the following criteria:"
      end
      #Reload Concept Edge to get the child relation
      concept_edge = @course.concept_edges.where(id: params["concept_edge_id"]).first
      concept_option = concept_edge.concept_option
      if params.has_key?(:correct_threshold)
        result += "\n" + set_concept_correct_threshold(concept_option, params[:correct_threshold])
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

  def get_concept_relation
    concept_edge = @course.concept_edges.where(id: params["concept_edge_id"]).first
    if !concept_edge.nil?
      result = {
                 concept_edge_id: concept_edge.id,
                 enabled: false,
                 correct_threshold: 0
               }
      concept_option = concept_edge.concept_option
      if !concept_option.nil?
        result[:enabled] = concept_option.enabled
        correct_threshold = concept_option.concept_criteria.correct_threshold_subcriteria.first
        if !correct_threshold.nil?
          result[:correct_threshold] = correct_threshold.threshold
        end
      end

      respond_to do |format| 
        format.json { render json: result}
      end
    else
      raise "Concept edge id is invalid"
    end
  end

  def set_concept_correct_threshold(concept_option, correct_threshold_amt)

    result = "\n[ Correct Threshold ]"
    correct_threshold_single = concept_option.concept_criteria.correct_threshold_subcriteria.first

    if !correct_threshold_single.nil?
      correct_threshold_criterion = correct_threshold_single.specific
    else
      correct_threshold_criterion = Assessment::CorrectThreshold.new
      correct_threshold_criterion.guidance_concept_option = concept_option
    end

    #Match integers only
    if correct_threshold_amt =~ /^(-|\+)?(\d+)$/
      amt = correct_threshold_amt.to_i
      if amt > 0
        correct_threshold_criterion.threshold = amt
        correct_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        Assessment::GuidanceConceptCriterion.delete_with_new correct_threshold_criterion
        result += "\n - " + "Negative integer entered. Criteria deleted."
      end
    else
      result += "\n - " + "Non-integer entered. No changes made."
    end
    result
  end

  def access_denied

  end
end
