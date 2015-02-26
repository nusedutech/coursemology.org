class Assessment::GuidanceQuizSubmissionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :assessment, through: :course, class: "Assessment"
  load_and_authorize_resource :submission, through: :assessment, class: "Assessment::Submission"

  before_filter :authorize_and_load_guidance_quiz, only: [:attempt, :edit]

  #Create new guidance quiz entry
  def attempt
    concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first

    #Redirect when concept sent through POST is wrong, concept option doesn't exist
    #or if entering through the concept is not allowed
    if concept.nil? or concept.concept_option.nil? or !concept.concept_option.can_enter?
      redirect_to course_topicconcepts_path(@course), alert: " Invalid Concept Path!"
      return 
    end

    @submission = @assessment.submissions.where(std_course_id: curr_user_course).last
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

  end

  private

  #Setup the concept stage attempt in the submission
  def setup_concept_stages_from submission, concepts
    concepts.each do |concept|
      if !concept.concept_option.nil? and concept.concept_option.can_enter?
        concept_stage = submission.concept_stages.new
        concept_stage.topicconcept_id = concept.id
        concept_stage.save
        setup_concept_edge_stage_from concept_stage, concept.concept_edge_dependent_concepts
      end
    end
  end

  #Setup the concept stage edges attempt from the concept stage
  def setup_concept_edge_stage_from concept_stage, concept_edges
    concept_edges.each do |concept_edge|
      if !concept_edge.concept_edge_option.nil? and concept_edge.concept_edge_option.enabled
        concept_edge_stage = concept_stage.concept_edge_stages.new
        concept_edge_stage.concept_edge_id = concept_edge.id
        concept_edge_stage.save
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

    {is_correct: correct,
     result: correct ? correct_str : "Incorrect!",
     explanation: explanation,
		 answer_id: ans.id
    }
  end

  def authorize_and_load_guidance_quiz
    if curr_user_course.is_staff?
      return true
    end
 
    @guidance_quiz = @assessment.specific

    #No start time for guidance quiz, only can start after published
    unless @guidance_quiz.enabled
      redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!"
    end
  end
end
