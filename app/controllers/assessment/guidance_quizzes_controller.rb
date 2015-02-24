class Assessment::GuidanceQuizzesController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :guidance_quiz, class: "Assessment::GuidanceQuiz", through: :course
  before_filter :load_general_course_data, only: [:access_denied]


  #Only one guidance assessment per course, hence 
  #we use a collection method to constantly access it
  def set_enabled
    enabled = params[:data]

    if enabled == "true"
		  Assessment::GuidanceQuiz.enable(@course)
    else
      Assessment::GuidanceQuiz.disable(@course)
    end
    
    respond_to do |format| 
      format.json { render json: { result: true}}
    end
  end

  def set_passing_edge_lock
    enabled = params[:data]
		Assessment::GuidanceQuiz.set_passing_edge_lock(@course, enabled == "true")
    
    respond_to do |format| 
      format.json { render json: { result: true}}
    end
  end

  def set_neighbour_entry_lock
    enabled = params[:data]
		Assessment::GuidanceQuiz.set_neighbour_entry_lock(@course, enabled == "true")
    
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
      result = get_concept_edge_relation_with concept_edge

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
      result = get_concept_criteria_with concept

      respond_to do |format| 
        format.json { render json: result}
      end
    else
      raise "Concept id is invalid"
    end
  end

  def get_topicconcept_data_with_criteria    
    respond_to do |format|
      @topics_concepts_with_info = []
      get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
      @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}
      
      @concepts = @course.topicconcepts.concepts
      @concepts_with_criteria = @concepts.map { |c| (get_concept_criteria_with c).merge({ concept_name: c.name}) }

      @concept_edges = ConceptEdge.joins("INNER JOIN topicconcepts ON topicconcepts.id = concept_edges.dependent_id").where(:topicconcepts => {:course_id => @course.id})
      @concept_edges_with_criteria = @concept_edges.map { |ce| (get_concept_edge_relation_with ce).merge({ dependent_id: ce.dependent_id, required_id: ce.required_id}) }
 
      format.json { render :json =>{:topictrees => @topics_concepts_with_info,
                                    :nodelist => @concepts_with_criteria,
                                    :edgelist => @concept_edges_with_criteria,
                                    :lastAtmNode => nil,
                                    :openAtmNodes => {},
                                    :lastAtmEdges => {},
                                    :openAtmEdges => {}
                                   }
                  }    
   
    end    
  end

  #Action for student view on topicconcept map
  def get_guidance_concept_data
    @concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first
    result = {}

    if !@concept.nil?
      concept_criteria = get_concept_criteria_student_progress_with @concept
      if concept_criteria[:enabled]
        result[:criteria] = concept_criteria[:criteria]
      else
        result[:criteria] = []
      end
      result = result.merge(get_guidance_concept_action_with concept_criteria)
      result[:name] = @concept.name;
      result[:raw_right] = @concept.all_raw_correct_answer_attempts(curr_user_course.id).size
      result[:raw_total] = result[:raw_right] + @concept.all_raw_wrong_answer_attempts(curr_user_course.id).size
      latest_answers = @concept.all_latest_answer_attempts(curr_user_course.id)
      result[:latest_right] = latest_answers[:correct].size
      result[:latest_total] = latest_answers[:correct].size + latest_answers[:wrong].size
      optimistic_answers = @concept.all_optimistic_answer_attempts(curr_user_course.id)
      result[:optimistic_right] = optimistic_answers[:correct].size
      result[:optimistic_total] = optimistic_answers[:correct].size + optimistic_answers[:wrong].size
      pessimistic_answers = @concept.all_pessimistic_answer_attempts(curr_user_course.id)
      result[:pessimistic_right] = pessimistic_answers[:correct].size
      result[:pessimistic_total] = pessimistic_answers[:correct].size + pessimistic_answers[:wrong].size
    else
      result[:access_denied] = "Incorrect concept parameters sent." 
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  #Action for student view on topicconcept map
  def get_guidance_concept_edge_data
    @concept_edge = @course.concept_edges.where(required_id: params[:required_concept_id],
                                                dependent_id: params[:dependent_concept_id] ).first
    result = {}

    if !@concept_edge.nil?
      concept_edge_criteria = get_concept_edge_relation_student_progress_with @concept_edge
      if concept_edge_criteria[:enabled]
        result[:criteria] = concept_edge_criteria[:criteria]
      else
        result[:criteria] = []
      end      
    else
      result[:access_denied] = "Incorrect concept edge parameters sent." 
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  #Everything beyond here are shortcut methods to make people's lives easier
  private

  #Get the user action required with the current criteria
  def get_guidance_concept_action_with criteria_hash
    action = ""
    actionUrl = ""

    if criteria_hash[:enabled] and Assessment::GuidanceQuiz.is_enabled? (@course)
      @guidance_quiz = @course.guidance_quizzes.first
      submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id,
                                                    status: "submitted").first

      #Path to create new submission entered at current criteria
      if submission.nil? and criteria_hash[:is_entry]
        action = "entry"
        actionUrl = ""
      #Path to currently locked
      elsif submission.nil?
        action = "enabled"
      #Path to resume submission at current criteria  
      elsif false
        action = "resume"
        actionUrl = ""
      else
        action = "none"
      end
    else
      action = "none"
    end

    return {action: action, actionURL: actionUrl}
  end

  #Get failing criteria for a concept
  def get_concept_criteria_student_progress_with concept
    result = {}
    concept_option = concept.concept_option
    if !concept_option.nil?
      result[:enabled] = concept_option.enabled
      result[:is_entry] = concept_option.is_entry
      result[:criteria] = compress_concept_criteria_student_progress_from concept_option
    #Default Values for display purposes
    else
      result[:enabled] = false
      result[:is_entry] = false
      result[:criteria] = []
    end
    result
  end

  def compress_concept_criteria_student_progress_from concept_option
    result = []

    #Retrieve criteria info
    concept_option.concept_criteria.each do |criterion|
      singleSummary = {}
      case (criterion.specific.is_type)
        when "wrong_threshold"
          singleSummary[:name] = "wrong_threshold"
          singleSummary[:pass] = true
          singleSummary[:current] = "?" 
          singleSummary[:condition] = criterion.specific.threshold
      end

      result << singleSummary
    end
    result
  end

  #Get passing criteria for an edge for student progress
  def get_concept_edge_relation_student_progress_with concept_edge
    result = {}
    concept_edge_option = concept_edge.concept_edge_option
    if !concept_edge_option.nil?
      result[:enabled] = concept_edge_option.enabled
      result[:criteria] = compress_concept_edge_criteria_student_progress_from concept_edge_option
    else
      result[:enabled] = false
      result[:criteria] = []
    end
   
    result
  end

  #Retrieve relation / passing criteria from a single edge based option for student progress
  def compress_concept_edge_criteria_student_progress_from concept_edge_option
    result = []

    #Retrieve criteria info
    concept_edge_option.concept_edge_criteria.each do |criterion|
      singleSummary = {}
      case (criterion.specific.is_type)
        when "correct_threshold"
          singleSummary[:name] = "correct_threshold"
          singleSummary[:pass] = false
          singleSummary[:current] = "?" 
          singleSummary[:condition] = criterion.specific.threshold
      end
      result << singleSummary
    end
    result
  end

  #Get failing criteria for a concept
  def get_concept_criteria_with concept
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
    result
  end

  def get_topic_tree(parent ,included_topicconcepts)
    included_topicconcepts.each do |itc|      
      @topics_concepts_with_info << {
        itc: itc,
        parent: parent
      }
      if !itc.included_topicconcepts.empty?
        get_topic_tree(itc, itc.included_topicconcepts)
      end
    end
  end

  #Get passing criteria for an edge
  def get_concept_edge_relation_with concept_edge
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
   
    result
  end

  #Get failing criteria for a concept
  def get_concept_criteria_with concept
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
    result
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
