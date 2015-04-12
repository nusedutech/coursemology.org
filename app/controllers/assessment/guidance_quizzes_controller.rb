class Assessment::GuidanceQuizzesController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :guidance_quiz, class: "Assessment::GuidanceQuiz", through: :course
  
  before_filter :load_general_course_data, only: [:access_denied]

  before_filter :load_guidance_quiz_singleton_with_submission, only: [:get_topicconcept_data_with_criteria, :get_guidance_concept_data, :get_guidance_concept_data_no_stats, :get_guidance_concept_edge_data, :get_guidance_concept_edges_data]

  before_filter :load_guidance_quiz_singleton, only: [:get_topicconcept_data_history, :get_scoreboard_data]

  before_filter :set_topicconcept_updated_timing, only: [:set_concept_edge_relation, :set_concept_edges_relation, :set_concept_criteria, :set_concepts_criteria]

  TOPIC_PASSED_STATUS = "passed"
  TOPIC_NONE_STATUS = "none"
  TOPIC_FAILED_STATUS = "failed"

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

  def set_feedback_data
    if params.has_key?("best_unattempted_weight") and
       params.has_key?("notbest_unattempted_weight") and
       integer_check params["best_unattempted_weight"] and
       integer_check params["notbest_unattempted_weight"] and
       params["best_unattempted_weight"].to_i >= 0 and
       params["best_unattempted_weight"].to_i <= 100 and
       params["notbest_unattempted_weight"].to_i >= 0 and
       params["notbest_unattempted_weight"].to_i <= 100

      Assessment::GuidanceQuiz.set_feedback_controls @course,
                                                     params.has_key?("show_scoreboard"),
                                                     params["best_unattempted_weight"].to_i,
                                                     params["notbest_unattempted_weight"].to_i
    end

    redirect_to course_preferences_path(@course)+"?_tab=topicconcept"
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
        result += "\n" + set_concept_edge_correct_threshold(concept_edge_option, 
                                                            params[:correct_threshold])
      end
      if params.has_key?(:correct_rating_threshold) and params.has_key?(:correct_rating_choice)
        result += "\n" + set_concept_edge_correct_rating_threshold(concept_edge_option, 
                                                            params[:correct_rating_threshold], 
                                                            params[:correct_rating_choice]=="true")
      end
      if params.has_key?(:correct_percent_threshold)
        result += "\n" + set_concept_edge_correct_percent_threshold(concept_edge_option, 
                                                            params[:correct_percent_threshold])
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

  def set_concept_edges_relation
    concept_edge_ids = JSON.parse(params[:tags]).map { |tag| tag["id"] }
    get_all_concept_edges = false
    concept_edge_ids.each do |concept_edge_id|
      if concept_edge_id == "nil"
        get_all_concept_edges = true
        break
      end
    end
    if get_all_concept_edges
      concept_edges = @course.concept_edges
    else
      concept_edges = @course.concept_edges.where(id: concept_edge_ids)
    end

    if params.has_key?(:exclude_concept_edges_textext)
      concept_edges = @course.concept_edges - concept_edges
    end

    enabled = params.has_key?(:enabled)
    if params.has_key?(:correct_threshold)
      correct_threshold = params[:correct_threshold]
    else
      correct_threshold = 0
    end

    if params.has_key?(:correct_rating_threshold)
      correct_rating_threshold = params[:correct_rating_threshold]
      correct_rating_absolute = params.has_key?(:correct_rating_absolute)
    else
      correct_rating_threshold = 0
      correct_rating_absolute = false
    end

    if params.has_key?(:correct_percent_threshold)
      correct_percent_threshold = params[:correct_percent_threshold]
    else
      correct_percent_threshold = 0
    end

    concept_edges.each do |concept_edge|
      #Initialise / create concept option (if not created before)
      if enabled
        Assessment::GuidanceConceptEdgeOption.enable(concept_edge)
      else
        Assessment::GuidanceConceptEdgeOption.disable(concept_edge)
      end

      #Reload Concept Edge to get the child relation
      concept_edge = @course.concept_edges.where(id: concept_edge.id).first
      concept_edge_option = concept_edge.concept_edge_option
      set_concept_edge_correct_threshold(concept_edge_option,
                                         correct_threshold)
      set_concept_edge_correct_rating_threshold(concept_edge_option, 
                                                correct_rating_threshold, 
                                                correct_rating_absolute)
      set_concept_edge_correct_percent_threshold(concept_edge_option, 
                                                 correct_percent_threshold)
    end

    redirect_to course_preferences_path(@course)+"?_tab=topicconcept"
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

      if params.has_key?(:wrong_rating_threshold) and params.has_key?(:wrong_rating_absolute)
        result += "\n" + set_concept_wrong_rating_threshold(concept_option, params[:wrong_rating_threshold], params[:wrong_rating_absolute]=="true")
      end

      if params.has_key?(:wrong_percent_threshold)
        result += "\n" + set_concept_wrong_percent_threshold(concept_option, params[:wrong_percent_threshold])
      end

      respond_to do |format| 
        format.json { render json: { result: result}}
      end
    else
      respond_to do |format| 
        format.json { render json: { result: "Concept was not found"}}
      end
    end
  end

  def set_concepts_criteria
    concept_ids = JSON.parse(params[:tags]).map { |tag| tag["id"] }
    get_all_concepts = false
    concept_ids.each do |concept_id|
      if concept_id == "nil"
        get_all_concepts = true
        break
      end
    end

    if get_all_concepts
      concepts = @course.topicconcepts.concepts
    else
      concepts = @course.topicconcepts.concepts.where(id: concept_ids)
    end

    if params.has_key?(:exclude_concepts_textext)
      concepts = @course.topicconcepts.concepts - concepts
    end

    enabled = params.has_key?(:fail_enabled)
    is_entry = params.has_key?(:fail_is_entry)
    if params.has_key?(:fail_wrong_threshold)
      wrong_threshold = params[:fail_wrong_threshold]
    else
      wrong_threshold = 0
    end

    if params.has_key?(:fail_wrong_rating_threshold)
      wrong_rating_threshold = params[:fail_wrong_rating_threshold]
      wrong_rating_absolute = params.has_key?(:fail_wrong_rating_absolute)
    else
      wrong_rating_threshold = 0
      wrong_rating_absolute = false
    end

    if params.has_key?(:fail_wrong_percent_threshold)
      wrong_percent_threshold = params[:fail_wrong_percent_threshold]
    else
      wrong_percent_threshold = 0
    end

    concepts.each do |concept|
      attributes = { 
        enabled: enabled,
        is_entry: is_entry
      }
      #Initialise / create concept option (if not created before)
      concept_option = Assessment::GuidanceConceptOption.update_attributes_with_new concept, attributes
      set_concept_wrong_threshold(concept_option, wrong_threshold)
      set_concept_wrong_rating_threshold(concept_option, wrong_rating_threshold, wrong_rating_absolute)
      set_concept_wrong_percent_threshold(concept_option, wrong_percent_threshold)

    end

    redirect_to course_preferences_path(@course)+"?_tab=topicconcept"
  end

  def get_concept_criteria
    concept = @course.topicconcepts.concepts.where(id: params["concept_id"]).first
    if !concept.nil?
      result = get_concept_criteria_with concept

      respond_to do |format| 
        format.json { render json: result}
      end
    else
      access_denied "Concept id is invalid!", course_topicconcepts_path(@course)
    end
  end

  def get_topicconcept_data_with_criteria    
    respond_to do |format|
      @topics_concepts_with_info = []
      get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
      @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}
      
      @concepts = @course.topicconcepts.concepts
      @concept_edges = ConceptEdge.joins("INNER JOIN topicconcepts ON topicconcepts.id = concept_edges.dependent_id").where(:topicconcepts => {:course_id => @course.id})
      
      submission_valid = (!@submission.nil? and @submission.attempting?)
      result =  { 
      	          topictrees: @topics_concepts_with_info, 
      	          submission: submission_valid
      	        }

      #Retrieve more information if has valid submission
      if submission_valid 
      	result.merge!(get_guidance_quiz_submission_data @submission)
      	afflictedNodes = result[:openAtmNodes] + result[:failedNodes] + [result[:lastAtmNode]]
      	@concepts = @concepts - afflictedNodes
      	afflictedEdges = result[:openAtmEdges] + result[:failedEdges]
      	@concept_edges = @concept_edges - afflictedEdges 
      end
      
      result[:nodelist] = @concepts.map { |c| (get_concept_criteria_with c).merge({ concept_name: c.name}) }
      result[:edgelist] = @concept_edges.map { |ce| (get_concept_edge_relation_with ce).merge({ dependent_id: ce.dependent_id, required_id: ce.required_id}) }
      
      format.json { render json: result }    
    end    
  end

  def get_topicconcept_data_history
    respond_to do |format|
      @topics_concepts_with_info = []
      get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
      @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}
      
      @concepts = @course.topicconcepts.concepts
      @concept_edges = ConceptEdge.joins("INNER JOIN topicconcepts ON topicconcepts.id = concept_edges.dependent_id").where(:topicconcepts => {:course_id => @course.id})
      
      submission = load_and_authorize_submission_with_id params[:submission_id]
      submission_valid = !submission.nil?
      result =  { 
                  topictrees: @topics_concepts_with_info, 
                  submission: submission_valid
                }

      #Retrieve more information if has valid submission
      if submission_valid 
        result.merge!(get_guidance_quiz_submission_data submission)
        afflictedNodes = result[:openAtmNodes] + result[:failedNodes] + [result[:lastAtmNode]]
        @concepts = @concepts - afflictedNodes
        afflictedEdges = result[:openAtmEdges] + result[:failedEdges]
        @concept_edges = @concept_edges - afflictedEdges 
      end
      
      result[:nodelist] = @concepts.map { |c| (get_concept_criteria_with c).merge({ concept_name: c.name}) }
      result[:edgelist] = @concept_edges.map { |ce| (get_concept_edge_relation_with ce).merge({ dependent_id: ce.dependent_id, required_id: ce.required_id}) }
      
      format.json { render json: result }    
    end
  end

  def get_guidance_quiz_submission_data submission
  	result = {}
    passed_concept_stages = Assessment::GuidanceConceptStage.get_passed_stages submission
    failed_concept_stages = Assessment::GuidanceConceptStage.get_failed_stages submission
    result[:openAtmNodes] = passed_concept_stages.collect(&:concept).uniq
    result[:failedNodes] = failed_concept_stages.collect(&:concept).uniq 

    latest_concept_stage = passed_concept_stages.first
    if !latest_concept_stage.nil?
      concept = latest_concept_stage.concept
      result[:lastAtmNode] = concept
      result[:openAtmNodes] = result[:openAtmNodes] - [concept]
      result[:failedNodes] = result[:failedNodes] - [concept]
    else
      result[:lastAtmNode] = nil
    end
    
    all_stages = passed_concept_stages + failed_concept_stages
    all_atm_edges = []
    all_stages.each do |stage|
      all_atm_edges = all_atm_edges + (Assessment::GuidanceConceptEdgeStage.get_passed_edge_stages stage)
    end
    failed_edges = []
    all_stages.each do |stage|
      failed_edges = failed_edges + (Assessment::GuidanceConceptEdgeStage.get_failed_edge_stages stage)
    end

    result[:openAtmEdges] = all_atm_edges.collect(&:concept_edge).uniq
    result[:failedEdges] = failed_edges.collect(&:concept_edge).uniq
    result
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
      result = result.merge(get_guidance_concept_action_with @concept, concept_criteria)
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

  #Action for student view on showing criteria
  def get_guidance_concept_data_no_stats
    @concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first
    result = {}

    if !@concept.nil?
      concept_criteria = get_concept_criteria_student_progress_with @concept
      if concept_criteria[:enabled]
        result[:criteria] = concept_criteria[:criteria]
      else
        result[:criteria] = []
      end

      respond_to do |format|
        format.json { render json: result}
      end 
    else
      access_denied "Concept id is invalid!", course_topicconcepts_path(@course)
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

  #Action for student view on showing edges criteria from one concept
  def get_guidance_concept_edges_data
    concept_edges = @course.concept_edges.where(required_id: params[:concept_id] )

      result = []

    concept_edges.each do |concept_edge|
      concept_edge_criteria = get_concept_edge_relation_student_progress_with concept_edge
      if concept_edge_criteria[:enabled]
        result << { name: concept_edge.dependent_concept.name, criteria: concept_edge_criteria[:criteria]}
      end
    end

    respond_to do |format|
      format.json { render json: result}
    end
  end

  #Get scoreboard data across students attempting submissions
  def get_scoreboard_data
    unless @guidance_quiz.feedback_show_scoreboard
      respond_to do |format|
        format.json { render json: { access_denied: "Scoreboard not enabled!" } }
      end
    end

    score_data = @guidance_quiz.submissions
                               .attempting_format
                               .joins(:std_course)
                               .where("assessment_submissions.std_course_id = user_courses.id")
                               .joins("INNER JOIN users ON users.id = user_courses.user_id")
                               .joins(:concept_stages)
                               .select("users.profile_photo_url as img, user_courses.name, SUM(assessment_guidance_concept_stages.rating_right) as rating")
                               .where("assessment_submissions.id = assessment_guidance_concept_stages.assessment_submission_id and assessment_guidance_concept_stages.failed = 0")
                               .group("assessment_guidance_concept_stages.assessment_submission_id")
                               .order("rating DESC")
                               .limit(10)


    respond_to do |format|
      format.json { render json: score_data}
    end
  end

  #Everything beyond here are shortcut methods to make people's lives easier
  private

  #Get the user action required with the current criteria
  def get_guidance_concept_action_with concept, criteria_hash
    action = ""
    actionUrl = ""
    actionUrlItems = ""

    if criteria_hash[:enabled]
      #Path to create new submission entered at current criteria
      if @submission.nil? and criteria_hash[:is_entry]
        action = "entry"
        actionUrl = attempt_course_assessment_guidance_quiz_submissions_path(@course, @guidance_quiz.assessment)
        actionUrlItems = { concept_id: concept.id }
      #Path to currently locked
      elsif @submission.nil?
        action = "enabled"
      #Path to resume submission at current criteria  
      else
        concept_stage = Assessment::GuidanceConceptStage.get_stage @submission, concept
        if !concept_stage.nil? and !concept_stage.failed
          action = "resume"
          actionUrl = diagnostic_exploration_course_topicconcept_path(@course, @concept)
        elsif !concept_stage.nil? and concept_stage.failed
          action = "failed"
        else
          action = "none"
        end
      end
    else
      action = "none"
    end

    return {action: action, actionURL: actionUrl, actionURLItems: actionUrlItems}
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
    current_correct = 0
    current_wrong = 0
    rating_right = 0
    rating_wrong = 0

    #Get submission records if it exist
    if @submission
      concept_stage = Assessment::GuidanceConceptStage.get_stage @submission, concept_option.topicconcept
      if concept_stage
        current_wrong = concept_stage.total_wrong
        current_right = concept_stage.total_right
        rating_right = concept_stage.rating_right
        rating_wrong = concept_stage.rating_wrong
      end
    end
    #Retrieve criteria info
    concept_option.concept_criteria.each do |criterion|
      singleSummary = {}
      case (criterion.specific.is_type)
        when "wrong_threshold"
          singleSummary[:name] = "wrong_threshold"
          singleSummary[:pass] = criterion.specific.evaluate current_wrong
          singleSummary[:current] = current_wrong.to_s 
          singleSummary[:condition] = criterion.specific.threshold
        when "wrong_rating_threshold"
          singleSummary[:name] = "wrong_rating_threshold"
          singleSummary[:pass] = criterion.specific.evaluate rating_right, rating_wrong
          singleSummary[:current] = criterion.specific.get_current rating_right, rating_wrong
          singleSummary[:condition] = criterion.specific.threshold
          singleSummary[:condition2] = criterion.specific.absolute
        when "wrong_percent_threshold"  
          singleSummary[:name] = "wrong_percent_threshold"
          singleSummary[:pass] = criterion.specific.evaluate current_right, current_wrong
          singleSummary[:current] = "%.1f" % (criterion.specific.get_current current_right, current_wrong)
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
    current_correct = 0
    current_wrong = 0
    rating_right = 0
    rating_wrong = 0

    #Get submission records if it exist
    if @submission
      concept_edge = concept_edge_option.concept_edge
      concept_stage = Assessment::GuidanceConceptStage.get_passed_stage @submission, concept_edge.required_concept
      if concept_stage
        concept_edge_stage = Assessment::GuidanceConceptEdgeStage.get_stage concept_stage, concept_edge
        if concept_edge_stage
          current_wrong = concept_edge_stage.total_wrong
          current_correct = concept_edge_stage.total_right
          rating_right = concept_edge_stage.rating_right
          rating_wrong = concept_edge_stage.rating_wrong
        end
      end
    end
    #Retrieve criteria info
    concept_edge_option.concept_edge_criteria.each do |criterion|
      singleSummary = {}
      case (criterion.specific.is_type)
        when "correct_threshold"
          singleSummary[:name] = "correct_threshold"
          singleSummary[:pass] = criterion.specific.evaluate current_correct
          singleSummary[:current] = current_correct
          singleSummary[:condition] = criterion.specific.threshold
        when "correct_rating_threshold"
          singleSummary[:name] = "correct_rating_threshold"
          singleSummary[:pass] = criterion.specific.evaluate rating_right, rating_wrong
          singleSummary[:current] = criterion.specific.get_current rating_right, rating_wrong
          singleSummary[:condition] = criterion.specific.threshold
          singleSummary[:condition2] = criterion.specific.absolute
        when "correct_percent_threshold"  
          singleSummary[:name] = "correct_percent_threshold"
          singleSummary[:pass] = criterion.specific.evaluate current_correct, current_wrong
          singleSummary[:current] = "%.1f" % (criterion.specific.get_current current_correct, current_wrong)
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
    #Default is passed - will check to reach none or failed status
    parent_status = TOPIC_PASSED_STATUS

    included_topicconcepts.each do |itc|  
      if !itc.included_topicconcepts.empty?
        #Status is dependent on collective children status
        status = get_topic_tree(itc, itc.included_topicconcepts)
        parent_status = status === TOPIC_PASSED_STATUS ? parent_status : TOPIC_NONE_STATUS
      elsif itc.is_concept? and !@submission.nil?
        concept_stage = Assessment::GuidanceConceptStage.get_stage @submission, itc
        if concept_stage.nil?
          parent_status = status = TOPIC_NONE_STATUS
        else        
          status = concept_stage.failed ? TOPIC_FAILED_STATUS : TOPIC_PASSED_STATUS
          #parent status to be none the moment one concept is failed
          parent_status = concept_stage.failed ? TOPIC_NONE_STATUS : parent_status
        end
      else
        #Status is passed (Since no failing child)
        status = TOPIC_PASSED_STATUS
      end
      @topics_concepts_with_info << {
        itc: itc,
        parent: parent,
        status: status
      }
    end

    parent_status
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

  #Retrieve relation / passing criteria from a single edge based option
  def compress_concept_edge_criteria_from concept_edge_option
    result = default_concept_edge_criteria_values

    #Retrieve criteria info
    concept_edge_option.concept_edge_criteria.each do |criterion|
      case (criterion.specific.is_type)
        when "correct_threshold"
          result[:correct_threshold] = criterion.specific.threshold
        when "correct_rating_threshold"
          result[:correct_rating_threshold] = criterion.specific.threshold
          result[:correct_rating_absolute] = criterion.specific.absolute
        when "correct_percent_threshold"
          result[:correct_percent_threshold] = criterion.specific.threshold
      end
    end
    result
  end

  #Initial Default values - future pref values can be set here
  def default_concept_edge_criteria_values
    {
      correct_threshold: 0,
      correct_rating_threshold: 0,
      correct_rating_absolute: false,
      correct_percent_threshold: 0,
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
        when "wrong_rating_threshold"
          result[:wrong_rating_threshold] = criterion.specific.threshold
          result[:wrong_rating_absolute] = criterion.specific.absolute
        when "wrong_percent_threshold"
          result[:wrong_percent_threshold] = criterion.specific.threshold
      end
    end
    result
  end

  #Initial Default values - future pref values can be set here
  def default_concept_criteria_values
    {
      wrong_threshold: 0,
      wrong_rating_threshold: 0,
      wrong_rating_absolute: false,
      wrong_percent_threshold: 0
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

  def set_concept_edge_correct_rating_threshold(concept_edge_option, correct_rating_threshold_amt, correct_rating_choice)

    result = "\n[ Correct Rating Threshold ]"
    correct_rating_threshold_single = concept_edge_option.concept_edge_criteria.correct_rating_threshold_subcriteria.first

    if !correct_rating_threshold_single.nil?
      correct_rating_threshold_criterion = correct_rating_threshold_single.specific
    else
      correct_rating_threshold_criterion = Assessment::CorrectRatingThreshold.new
      correct_rating_threshold_criterion.guidance_concept_edge_option = concept_edge_option
    end

    #Match integers only
    if integer_check correct_rating_threshold_amt
      amt = correct_rating_threshold_amt.to_i
      if amt > 0
        correct_rating_threshold_criterion.threshold = amt
        correct_rating_threshold_criterion.absolute = correct_rating_choice
        correct_rating_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        correct_rating_threshold_criterion.destroy
        result += "\n - " + "0 / Negative integer entered. Criteria deleted."
      end
    else
      result += "\n - " + "Non-integer entered. No changes made."
    end
    result
  end

  def set_concept_edge_correct_percent_threshold(concept_edge_option, correct_percent_threshold_amt)

    result = "\n[ Correct Percent Threshold ]"
    correct_percent_threshold_single = concept_edge_option.concept_edge_criteria.correct_percent_threshold_subcriteria.first

    if !correct_percent_threshold_single.nil?
      correct_percent_threshold_criterion = correct_percent_threshold_single.specific
    else
      correct_percent_threshold_criterion = Assessment::CorrectPercentThreshold.new
      correct_percent_threshold_criterion.guidance_concept_edge_option = concept_edge_option
    end

    #Match integers only
    if integer_check correct_percent_threshold_amt
      amt = correct_percent_threshold_amt.to_i
      if amt > 0
        correct_percent_threshold_criterion.threshold = amt
        correct_percent_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        correct_percent_threshold_criterion.destroy
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

  def set_concept_wrong_rating_threshold(concept_option, wrong_rating_threshold_amt, absolute_choice)

    result = "\n[ Wrong Rating Threshold ]"
    wrong_rating_threshold_single = concept_option.concept_criteria.wrong_rating_threshold_subcriteria.first

    if !wrong_rating_threshold_single.nil?
      wrong_rating_threshold_criterion = wrong_rating_threshold_single.specific
    else
      wrong_rating_threshold_criterion = Assessment::WrongRatingThreshold.new
      wrong_rating_threshold_criterion.guidance_concept_option = concept_option
    end

    #Match integers only
    if integer_check wrong_rating_threshold_amt
      amt = wrong_rating_threshold_amt.to_i
      if amt > 0
        wrong_rating_threshold_criterion.threshold = amt
        wrong_rating_threshold_criterion.absolute = absolute_choice
        wrong_rating_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        wrong_rating_threshold_criterion.destroy
        result += "\n - " + "0 / Negative integer entered. Criteria deleted."
      end
    else
      result += "\n - " + "Non-integer entered. No changes made."
    end
    result
  end

  def set_concept_wrong_percent_threshold(concept_option, wrong_percent_threshold_amt)

    result = "\n[ Wrong Percent Threshold ]"
    wrong_percent_threshold_single = concept_option.concept_criteria.wrong_percent_threshold_subcriteria.first

    if !wrong_percent_threshold_single.nil?
      wrong_percent_threshold_criterion = wrong_percent_threshold_single.specific
    else
      wrong_percent_threshold_criterion = Assessment::WrongPercentThreshold.new
      wrong_percent_threshold_criterion.guidance_concept_option = concept_option
    end

    #Match integers only
    if integer_check wrong_percent_threshold_amt
      amt = wrong_percent_threshold_amt.to_i
      if amt > 0 and amt <= 100
        wrong_percent_threshold_criterion.threshold = amt
        wrong_percent_threshold_criterion.save
        result += "\n - " + "Positive integer entered. Criteria updated."
      else
        wrong_percent_threshold_criterion.destroy
        result += "\n - " + "0 / Negative integer or > 100% entered. Criteria deleted."
      end
    else
      result += "\n - " + "Non-integer entered. No changes made."
    end
    result
  end

  def integer_check unit
    unit =~ /^(-|\+)?(\d+)$/
  end

  def load_guidance_quiz_singleton_with_submission
    @guidance_quiz = Assessment::GuidanceQuiz.get_guidance_quiz (@course)

    if @guidance_quiz.nil? or !@guidance_quiz.enabled
      respond_to do |format|
      	format.html { redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!" }
      	format.json { render json: { access_denied: "Not opened yet!" } }
      end
      return
    end 

    @submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id,
                                                   status: "attempting").first
    data_synchronise_submission @submission
  end

  def load_and_authorize_submission_with_id submission_id
    if curr_user_course.is_staff?
      submission = @guidance_quiz.submissions.where(id: submission_id).first
    else
      submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id, id: submission_id).first
    end
    data_synchronise_submission submission
    submission
  end

  def load_guidance_quiz_singleton
    @guidance_quiz = Assessment::GuidanceQuiz.get_guidance_quiz (@course)

    if @guidance_quiz.nil? or !@guidance_quiz.enabled
      respond_to do |format|
        format.html { redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!" }
        format.json { render json: { access_denied: "Not opened yet!" } }
      end
      return
    end 
  end

  def set_topicconcept_updated_timing
    @course.topicconcepts_updated_timing_singleton.set_updated_timing
  end

  #Check for synchronisation requirements
  def data_synchronise_submission submission
    if submission and (@course.topicconcepts_updated_timing_singleton.update_required submission.updated_at)
      Assessment::GuidanceConceptStage.data_synchronisation submission, !@guidance_quiz.neighbour_entry_lock
      submission.set_updated_timing
    end
  end

  #Check for synchronisation requirements
  def data_synchronise_submissions submissions
    submissions.each do |submission|
      data_synchronise_submission submission
    end
  end

  def access_denied message, redirectURL
    respond_to do |format|
      format.json { 
        render json: { 
          access_denied: { 
            message: message, 
            redirectURL: redirectURL
          } 
        } 
      }
    end
  end
end
