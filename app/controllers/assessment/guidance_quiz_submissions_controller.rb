class Assessment::GuidanceQuizSubmissionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :assessment, through: :course, class: "Assessment"
  load_and_authorize_resource :submission, through: :assessment, class: "Assessment::Submission", id_param: :id, only: [:edit, :submit, :set_tag_to_stage, :page_lost_focus]

  before_filter :authorize_and_load_guidance_quiz, only: [:attempt, :edit, :submit]
  before_filter :no_update_after_submission, only: [:edit, :submit]
  before_filter :authorize_and_load_guidance_quiz_and_concept_and_conceptstage, only: [:set_tag_to_stage, :page_lost_focus]


  #Create new guidance quiz entry
  def attempt
    concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first

    #Redirect when concept sent through POST is wrong, concept option doesn't exist
    #or if entering through the concept is not allowed
    if concept.nil? or concept.concept_option.nil? or !concept.concept_option.can_enter?
      redirect_to course_topicconcepts_path(@course), alert: " Invalid Concept Path!"
      return 
    end

    @submission = @assessment.submissions.submitted_format.where(std_course_id: curr_user_course).last
    #Create only when a submission is not found or if the last submission is submitted
    if @submission.nil? or @submission.submitted?
      @submission = @assessment.submissions.new
      @submission.std_course = curr_user_course
      @submission.save

      #Ensure guidance quiz setting - only one entry
      if @guidance_quiz.neighbour_entry_lock
        setup_concept_stages_from @submission, [concept] 
      else
        setup_concept_stages_from @submission, @course.topicconcepts.concepts
      end
    end

    redirect_to diagnostic_exploration_course_topicconcept_path(@course, concept)
  end

  def edit
    if (!params.has_key?(:concept_id) or !params.has_key?(:question_id) or !params.has_key?(:answers))
      access_denied "Insufficient parameters found", course_topicconcepts_path(@course)
      return
    end

    concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first
    if concept.nil?
      access_denied "Concept not found", course_topicconcepts_path(@course)
      return
    end

    concept_stage = Assessment::GuidanceConceptStage.get_passed_stage @submission, concept
    if concept_stage.nil?
      access_denied "You do not have access to the current concept (Your lecturer might have disabled it)", course_topicconcepts_path(@course)
      return
    end

    question_id = concept_stage.get_top_question_id_fast
    if question_id.nil?
      access_denied "Invalid question", course_topicconcepts_path(@course)
      return
    end

    if params[:question_id] != question_id
      access_denied "Invalid question", course_topicconcepts_path(@course)
      return
    end
    
    concept_stage.remove_top_question
    question = @course.questions.find_by_id(question_id).specific
    response = submit_mcq(question)
    concept_stage.record_answer(response[:answer])
    if (response[:is_correct])
      concept_stage.add_one_right @submission, @guidance_quiz.passing_edge_lock, question.totalRating
    else
      concept_stage.add_one_wrong @submission, @guidance_quiz.passing_edge_lock, question.totalRating 
    end

    #Launch second check to lock when evaluated fail status
    if concept_stage.check_to_lock_procedure @submission
      access_denied "You have failed this concept. Try again from the easier concepts.", course_topicconcepts_path(@course)
      return
    end

    unlocked_concepts = concept_stage.check_to_unlock_procedure @submission
    concept_names = unlocked_concepts.map {|c| c.name}

    respond_to do |format|
      format.json { 
        render json: { 
          correct: response[:is_correct], 
          explanation: style_format(response[:explanation]),
          unlocked_concepts: concept_names
        } 
      }
    end
  end

  def submit
    @submission.set_submitted

    redirect_to course_topicconcepts_path(@course)
  end

  def page_lost_focus
    @concept_stage.add_page_left_count

    respond_to do |format|
      format.json { 
        render json: {
        } 
      }
    end
  end

  def set_tag_to_stage
    if params.has_key?(:tag_id) and params[:tag_id] != @concept_stage.tag_id
      if params[:tag_id] == "nil"
        @concept_stage.set_tag nil, @course
      else
        param_tag = @course.tags.find_by_id(params[:tag_id])
        @concept_stage.set_tag param_tag, @course
      end
    end

    redirect_to diagnostic_exploration_course_topicconcept_path(@course, @concept)
  end

  private

  #Setup the concept stage attempt in the submission
  def setup_concept_stages_from submission, concepts
    concepts.each do |concept|
      if !concept.concept_option.nil? and concept.concept_option.can_enter?
        concept_stage = submission.concept_stages.new
        concept_stage.topicconcept_id = concept.id
        concept_stage.save
        setup_concept_edge_stage_from submission, concept_stage, concept.concept_edge_dependent_concepts
      end
    end
  end

  #Setup the concept stage edges attempt from the concept stage
  def setup_concept_edge_stage_from submission, concept_stage, concept_edges
    concept_edges.each do |concept_edge|
      concept_edge_option = concept_edge.concept_edge_option
      if !concept_edge_option.nil? and concept_edge_option.enabled
        concept_edge_stage = concept_stage.concept_edge_stages.new
        concept_edge_stage.concept_edge_id = concept_edge.id
        concept_edge_stage.save

        concept_edge_stage.check_to_unlock submission
      end
    end
  end

  def submit_mcq(question)
    if params[:answers].is_a?(Array)
      selected_options = question.options.find_all_by_id(params[:answers])
    else
      selected_options = question.options.find_all_by_id([params[:answers]])
    end
    eval_array = selected_options.map(&:correct)
    incomplete = false
    correct = eval_array.reduce {|x, y| x && y}

    if correct && question.select_all?
      correct = selected_options.length == question.options.where(correct: true).count
      incomplete = !correct
    end

    ans = Assessment::McqAnswer.create({std_course_id: curr_user_course.id,
                                        question_id: question.question.id,
                                        submission_id: @submission.id,
                                        correct: correct,
                                        finalised: correct
                                       })
    ans.answer_options.create(selected_options.map {|so| {option_id: so.id}})

    grade  = 0
    pref_grader = @course.mcq_auto_grader.prefer_value

    if correct && !@submission.graded?
      grade = AutoGrader.mcq_grader(@submission, ans.answer, question, pref_grader)
    end

    if pref_grader == 'two-one-zero'
      grade_str = grade > 0 ? " + #{grade}" : ""
      correct_str =  "Correct! #{grade_str}"
    else
      correct_str =  "Correct!"
    end

    if question.select_all?
      if incomplete
        explanation = "Not all correct answers are selected."
      else
        c_count = eval_array.select{|x| x}.length
        explanation = "#{c_count} correct, #{eval_array.length - c_count} wrong"
      end
    else
      explanation = selected_options.first.explanation
    end

    {
      is_correct: correct,
      result: correct ? correct_str : "Incorrect!",
      explanation: explanation,
		  answer: ans
    }
  end

  def authorize_and_load_guidance_quiz
  	@guidance_quiz = @assessment.specific
    data_synchronise_submission @submission
    if curr_user_course.is_staff?
      return true
    end

    #No start time for guidance quiz, only can start after published
    unless @guidance_quiz.enabled
      redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!"
    end
  end

  def no_update_after_submission
    unless @submission.attempting?
      access_denied "Submission is already submitted.", course_topicconcepts_path(@course)
    end
  end

  def authorize_and_load_guidance_quiz_and_concept_and_conceptstage
    #No start time for guidance quiz, only can start after published
    unless Assessment::GuidanceQuiz.is_enabled? @course
      redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!"
      return
    end

    @guidance_quiz = @course.guidance_quizzes.first
    data_synchronise_submission @submission
    unless params.has_key?(:concept_id)
      redirect_to course_topicconcepts_path(@course), alert: " Concept parameter not found!"
      return
    end

    @concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first
    if @concept.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Concept not found!"
      return
    end

    @concept_stage = Assessment::GuidanceConceptStage.get_passed_stage @submission, @concept
    unless @concept_stage
      redirect_to course_topicconcepts_path(@course), alert: " Choose concept first!"
      return
    end
  end

  #Check for synchronisation requirements
  def data_synchronise_submission submission
    if submission and (@course.topicconcepts_updated_timing_singleton.update_required submission.updated_at)
      Assessment::GuidanceConceptStage.data_synchronisation submission, !@guidance_quiz.neighbour_entry_lock
      submission.set_updated_timing
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
