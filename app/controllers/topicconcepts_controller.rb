class TopicconceptsController < ApplicationController
  include ERB::Util
  load_and_authorize_resource :course
  load_and_authorize_resource :topicconcept, through: :course

  before_filter :set_popup_layout, only: [:get_topicconcept_area, :review_diagnostic_exploration_on_stage]

  before_filter :load_general_course_data, only: [:index, :concept_questions, :get_topicconcept_rated_data, :get_topicconcept_overall_statistics, :diagnostic_exploration, :get_quiz_feedback, :individual_submissions, :get_topicconcept_weights, :review_diagnostic_exploration]

  before_filter :set_viewing_permissions, only:[:index, :diagnostic_exploration, :review_diagnostic_exploration, :get_quiz_feedback, :individual_submissions]

  before_filter :authorize_and_load_guidance_quiz, only:[:get_topicconcept_overall_statistics, :get_quiz_feedback, :individual_submissions, :get_topicconcept_weights, :get_topicconcept_area, :review_diagnostic_exploration_on_stage, :get_topicconcept_single_statistics, :get_topicconcept_single_current_statistics, :get_topicconcept_best_concepts, :get_topicconcept_notbest_concepts]

  before_filter :authorize_and_load_guidance_quiz_and_submission_and_concept_for_review, only: [:review_diagnostic_exploration]

  before_filter :authorize_and_load_guidance_quiz_and_submission_and_concept_for_index, only: [:index]

  before_filter :authorize_and_load_guidance_quiz_and_submission_and_concept_and_conceptstage, only: [:diagnostic_exploration, :diagnostic_exploration_next_question]

  before_filter :load_general_topicconcept_data, only: [:index, :diagnostic_exploration, :review_diagnostic_exploration, :get_progress_bar_info]

  before_filter :set_topicconcept_updated_timing, only: [:topic_concept_data_create, :topic_concept_data_delete, :topic_concept_data_move, :topic_concept_data_save_dependency]

  def index   

    @topics_concepts_with_info = []
    get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
    @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}
    #@topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank.split('.')[e[:itc].rank.split('.').length-1].to_i}

    Rails.cache.clear
  end
  
  def ivleapi   
    
  end

  def get_quiz_feedback
    @summary = {}

    sbms = @guidance_quiz.submissions.where(std_course_id: @course.student_courses)
    @summary[:attempting] = sbms.map { |sbm| sbm.std_course }
    @summary[:attempting] = @summary[:attempting].uniq
    @summary[:unsubmitted] = @course.student_courses - @summary[:attempting]

    if params.has_key?("freq_wrong_count")
      @freq_wrong_count = params["freq_wrong_count"].to_i
    else
      @freq_wrong_count = 5
    end

    if params.has_key?("correct") and params[:correct] == "true"
      @choose_correct = true
    else
      @choose_correct = false
    end

    if params.has_key?("tag_id") and params[:tag_id] != "nil"
      @tag = @course.tags.where(id: params[:tag_id]).first
    else
      @tag = nil
    end
    if params.has_key?("freq_concept_id") and params[:freq_concept_id] != "nil"
      @chosen_concept = @course.topicconcepts
                               .concepts
                               .where(id: params[:freq_concept_id])
                               .first
    else
      @chosen_concept = nil
    end

    @concepts = @course.topicconcepts.concepts
    if @chosen_concept and @tag
      tag_mcq_answers = @tag.mcq_answers
      combined_mcq_answers = @chosen_concept.mcq_answers
                                            .where("assessment_mcq_answers.id in (?)", tag_mcq_answers)
      @summary[:freq_wrong_questions] = @guidance_quiz.mcq_answers
                                                      .select("assessment_answers.question_id as qid, COUNT(*) as count")
                                                      .where("assessment_answers.correct = ? and assessment_mcq_answers.id in (?)",
                                                             @choose_correct,
                                                             combined_mcq_answers)
                                                      .group("qid")
                                                      .order("count DESC")
                                                      .limit(@freq_wrong_count)
    elsif @chosen_concept
      concept_mcq_answers = @chosen_concept.mcq_answers
      @summary[:freq_wrong_questions] = @guidance_quiz.mcq_answers
                                                      .select("assessment_answers.question_id as qid, COUNT(*) as count")
                                                      .where("assessment_answers.correct = ? and assessment_mcq_answers.id in (?)",
                                                             @choose_correct,
                                                             concept_mcq_answers)
                                                      .group("qid")
                                                      .order("count DESC")
                                                      .limit(@freq_wrong_count)
    elsif @tag
      tag_mcq_answers = @tag.mcq_answers
      @summary[:freq_wrong_questions] = @guidance_quiz.mcq_answers
                                                      .select("assessment_answers.question_id as qid, COUNT(*) as count")
                                                      .where("assessment_answers.correct = ? and assessment_mcq_answers.id in (?)",
                                                             @choose_correct,
                                                             tag_mcq_answers)
                                                      .group("qid")
                                                      .order("count DESC")
                                                      .limit(@freq_wrong_count)
    else
      @summary[:freq_wrong_questions] = @guidance_quiz.mcq_answers
                                                      .select("assessment_answers.question_id as qid, COUNT(*) as count")
                                                      .where("assessment_answers.correct = ?",@choose_correct)
                                                      .group("qid")
                                                      .order("count DESC")
                                                      .limit(@freq_wrong_count)
    end

    @tags = @course.tags
    @concepts = @course.topicconcepts.concepts
  end

  def diagnostic_exploration
    set_latest_concept_stage @concept_stage
    @question = @concept_stage.get_top_question @course

    @tags = @course.tags
    if !@concept_stage.tag_id.nil?
      #After tag is deleted, but stage is not updated,
      #we need to reassign questions again
      if @concept_stage.tag.nil?
        @concept_stage.set_uncompleted_questions_string @course
      end
    end

    if @question.nil?
      @question = @concept_stage.reset_and_get_top_question @course
    end

    unless @question
      redirect_to course_topicconcepts_path(@course), alert: " Current concept has run out of questions!"
      return
    end

    @current_tag =  @concept_stage.tag

    @title_concept = @concept
    respond_to do |format|
      format.html {
        render "topicconcepts/index"
      }
    end
  end

  def diagnostic_exploration_next_question
    set_latest_concept_stage @concept_stage
    question = @concept_stage.get_top_question @course

    if question.nil?
      question = @concept_stage.reset_and_get_top_question @course
    end

    unless question
      access_denied " Current concept has run out of questions!", course_topicconcepts_path(@course)
      return
    end

    if question.as_question.class == Assessment::McqQuestion
      mcq_question = question.specific
      options = mcq_question.options.map { |x| { id: x.id, text: style_format(html_escape(x.text)) } }
      summary = {
                  question_title: style_format(question.description),
                  question_id: question.id,
                  question_select_all: mcq_question.select_all,
                  question_options: options
                }
    else
      summary = {}
    end

    respond_to do |format|
      format.json {
        render json: summary
      }
    end
  end

  #Admin view on individual submissions
  def individual_submissions
  	if params.has_key?(:select_student) and params[:select_student] != ""
 			@student = @course.user_courses.find_by_id(params[:select_student])
 		end

 		if @student
 			@submissions = @guidance_quiz.submissions
 																	 .where(std_course_id: @student.id)
 																	 .order("created_at DESC")
 		else
 			@submissions = []
 		end

 		if @student and params.has_key?(:select_submission) and params[:select_submission] != ""
 			@chosen_submission = @guidance_quiz.submissions
 																				 .where(std_course_id: @student.id,
 																				 				id: params[:select_submission])
 																				 .first
      data_synchronise_submission @chosen_submission
 		end

 		if @chosen_submission
 			@concept_stages = Assessment::GuidanceConceptStage.get_passed_stages @chosen_submission
	    enabled_concepts = Topicconcept.joins("INNER JOIN assessment_guidance_concept_options ON assessment_guidance_concept_options.topicconcept_id = topicconcepts.id")
	                                   .concepts
	                                   .where(topicconcepts: {course_id: @course.id}, assessment_guidance_concept_options: {enabled: true})
	    @achieve_percentage = @concept_stages.size * 100 / enabled_concepts.size; 
	    @achieve_correct_amount = @chosen_submission.mcq_answers.where(assessment_answers: {correct: true}).size
	    @achieve_wrong_amount = @chosen_submission.mcq_answers.where(assessment_answers: {correct: false}).size 
	    @achieve_rating = 0
	    @concept_stages.each do |stage|
	      @achieve_rating += stage.rating_right
	    end
 		end
  end

  def review_diagnostic_exploration
    @submissions = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id).order("created_at DESC")

    if params.has_key?(:submission_id)
      @chosen_submission = load_and_authorize_submission_with_id params[:submission_id]
    end

    if @chosen_submission.nil?
      @chosen_submission = @latest_submission
    end

    @concept_stages = Assessment::GuidanceConceptStage.get_passed_stages @chosen_submission
    enabled_concepts = Topicconcept.joins("INNER JOIN assessment_guidance_concept_options ON assessment_guidance_concept_options.topicconcept_id = topicconcepts.id")
                                   .concepts
                                   .where(topicconcepts: {course_id: @course.id}, assessment_guidance_concept_options: {enabled: true})
    @achieve_percentage = @concept_stages.size * 100 / enabled_concepts.size; 
    @achieve_correct_amount = @chosen_submission.mcq_answers.where(assessment_answers: {correct: true}).size
    @achieve_wrong_amount = @chosen_submission.mcq_answers.where(assessment_answers: {correct: false}).size 
    @achieve_rating = 0
    @concept_stages.each do |stage|
      @achieve_rating += stage.rating_right
    end

    respond_to do |format|
      format.html {
        render "topicconcepts/index"
      }
    end
  end

  def review_diagnostic_exploration_on_stage

    unless params.has_key?(:submission_id) and params.has_key?(:concept_id)
      redirect_to course_topicconcepts_path(@course), alert: " Insufficent units provided!"
      return
    end

    @submission = load_and_authorize_submission_with_id params[:submission_id]
    if @submission.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Submission not found!"
      return
    end

    @concept = @course.topicconcepts.concepts.where(id: params[:concept_id]).first
    if @concept.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Concept not found!"
      return
    end
    @concept_stages = Assessment::GuidanceConceptStage.get_stages @submission

    @questions = []
    @question_total = 0;
    @question_right = 0;
    mcq_answers = @concept.mcq_answers.where(assessment_answers: {submission_id: @submission}).order("assessment_answers.updated_at DESC")
    mcq_answers.each do |single_answer|
      mcq_question = single_answer.question.specific
      question_summary = {}
      question_summary[:correct] = single_answer.correct
      question_summary[:description] = mcq_question.description
      question_summary[:right_option] = mcq_question.getCorrectOptions 

      #For incorrectly answered questions only
      if !single_answer.correct
        question_summary[:chosen_option] = []            
        single_answer.answer_options.each do |answer_option|
          question_summary[:chosen_option] << answer_option.option
        end
      else
        @question_right = @question_right + 1
      end
      @question_total = @question_total + 1
      @questions << question_summary
    end

    respond_to do |format|
      format.html
    end
  end

  def set_latest_concept_stage concept_stage
    concept_stage.updated_at = Time.now
    concept_stage.save
  end

  def raw_query_get_select_all mcq_id
    ActiveRecord::Base.establish_connection(
            :adapter => "mysql2",
            :host => "localhost",
            :database => "coursemology",
            :username => "root",
            :password => ""
      )
      sql = "SELECT * from assessment_mcq_questions where id = " + mcq_id.to_s
      return ActiveRecord::Base.connection.execute(sql).to_a[0][1]
  end
  
  def submit_answer
    respond_to do |format|
      concept = Topicconcept.find(params[:concept_id])
      question = concept.questions.where(:id => params[:question_id]).first
      answer = question.options.where(:id => params[:ans_id]).first
      if answer.correct
        format.json { render :json => {:result => 'correct'}}
      elsif
        format.json { render :json => {:result => 'fail'}}
      end
          
    end
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

  def get_topics_concepts_edges(one_node_array)
    one_node_array.each do |itc|
      @topics_concepts_children << itc
      if !itc.included_topicconcepts.empty?
        @topics_edges_children += itc.topic_edge_included_topicconcepts
        get_topics_concepts_edges(itc.included_topicconcepts)
      end
    end
  end
  
  def topic_concept_data_create
    tc = Topicconcept.new params[:topics_concept]
    topic_edge = TopicEdge.new params[:topic_edge]
    respond_to do |format|
      if topic_edge.parent_id
        pc = Topicconcept.find(topic_edge.parent_id) 
        tc.rank = pc.rank + '.' + (pc.included_topicconcepts.count + 1).to_s
        if tc.save
          topic_edge.included_topic_concept_id = tc.id         
          if topic_edge.save      
              format.json { render :json => { :result => tc.id, :test => topic_edge}}
          end
        end
      else
        tc.rank = (Topicconcept.where(:course_id => @course.id,:typename => 'topic').count + 1).to_s
        if tc.save
          format.json { render :json => { :result => tc.id}}
        end
      end      
    end
  end

  def topic_concept_data_rename
    tc = Topicconcept.find params[:id]
    tc.name = params[:name].empty? ? "undefined" : params[:name]
    respond_to do |format|
      if tc.save
        format.json { render :json => { :result => '1'}}
      end
    end
  end

  def topic_concept_data_delete
    @topics_concepts_children = []
    @topics_edges_children = []
    @dependency_edges_children = []    
    tc = Topicconcept.find params[:id]
    topic_edge = TopicEdge.find_by_parent_id_and_included_topic_concept_id(params[:parent],params[:id])
    get_topics_concepts_edges [tc]
    if @topics_concepts_children.count > 0
      @topics_concepts_children.uniq.each do |itc|
        @dependency_edges_children += itc.concept_edge_required_concepts
        @dependency_edges_children += itc.concept_edge_dependent_concepts
      end
    end
    
    flag = true  
    respond_to do |format|
      if @topics_edges_children.count > 0
        @topics_edges_children.uniq.each do |tec|
          if !tec.destroy
            flag = false
          end
        end
      end
      if @dependency_edges_children.count > 0
        @dependency_edges_children.uniq.each do |dec|
          if !dec.destroy
            flag = false
          end
        end
      end
      if @topics_concepts_children.count > 0
        @topics_concepts_children.uniq.each do |tcc|
          if !tcc.destroy
            flag = false
          end
        end
      end
      if !topic_edge.nil?
        if !topic_edge.destroy
          flag = false
        end
      end
      if flag
        format.json { render :json => { :result => '1'}}
      else
        format.json { render :json => { :result => 'delete fails'}}
      end    
    end
  end
  
  def topic_concept_data_move
    tc = Topicconcept.find params[:id]
    if params[:old_parent] && params[:old_parent] != "#"
      old_edge = TopicEdge.find_by_parent_id_and_included_topic_concept_id(params[:old_parent],params[:id])
    end
    if params[:parent] && params[:parent] != "#"
      new_edge = TopicEdge.new
      new_edge.parent_id = params[:parent]
      new_edge.included_topic_concept_id = params[:id]
      pc = Topicconcept.find(params[:parent])
      if pc.included_topicconcepts.count > 0 && params[:pos].to_i < pc.included_topicconcepts.count
        children_list = pc.included_topicconcepts.sort_by{|e| e.rank.split('.')[e.rank.split('.').length-1].to_i}
        pos_change = 0
        children_list.each_with_index do |pitc, index|
          if params[:pos].to_i == index && pos_change == 0
            pos_change = 1
            pitc.rank = pc.rank + '.' + (index + 1 + pos_change).to_s
          elsif pitc.id == tc.id && pos_change != 0
            tc.rank = pc.rank + '.' + (params[:pos].to_i + pos_change).to_s
            pos_change = 0
          elsif pitc.id == tc.id && pos_change == 0
            pos_change = -1
            tc.rank = pc.rank + '.' + (params[:pos].to_i + 1).to_s
          elsif params[:pos].to_i == index && pos_change != 0
            pitc.rank = pc.rank + '.' + (index + 1 + pos_change).to_s
            pos_change = 0
          else
            pitc.rank = pc.rank + '.' + (index + 1 + pos_change).to_s
          end
          pitc.save

        end
      else
        tc.rank = pc.rank + '.' + (params[:pos].to_i + 1).to_s
      end
              
    else
      topics = Topicconcept.where(:course_id => @course.id,:typename => 'topic')
      if topics.count > 0 && params[:pos].to_i < topics.count
        children_list = topics.sort_by{|e| e.rank}
        pos_change = 0
        children_list.each_with_index do |pitc, index|
          if params[:pos].to_i == index && pos_change == 0
            pos_change = 1
            pitc.rank = (index + 1 + pos_change).to_s
          elsif pitc.id == tc.id && pos_change != 0
            tc.rank = (params[:pos].to_i + pos_change).to_s
            pos_change = 0
          elsif pitc.id == tc.id && pos_change == 0
            pos_change = -1
            tc.rank = (params[:pos].to_i + 1).to_s
          elsif params[:pos].to_i == index && pos_change != 0
            pitc.rank = (index + 1 + pos_change).to_s
            pos_change = 0
          else
            pitc.rank = (index + 1 + pos_change).to_s
          end
          pitc.save
        end
      else
        tc.rank = (params[:pos].to_i + 1).to_s
      end
    end
    
    flag = true
    respond_to do |format|
      if !old_edge.nil?
        if !old_edge.destroy
          flag = false           
        end
      end
      if !new_edge.nil? && !new_edge.included_topic_concept_id.nil?
        if !new_edge.save
          flag = false
        end
      end
      if flag
        if tc.save
          format.json { render :json => { :result => '1'}}
        end
      end
    end
  end
  
  
  def topic_concept_data_dependency
    dc = Topicconcept.find params[:id]
    tc = Topicconcept.where(:course_id => @course.id, :typename => 'concept').select(:name)
    respond_to do |format|
      format.json { render :json => { :dependencies => dc.required_concepts, :concepts_list => tc.map { |e| e.name }}}      
    end
  end
  
  def get_concepts_list
    concepts = Topicconcept.where(:course_id => params[:course_id], :typename => "concept").select(:name)
    respond_to do |format|
      concepts_list = concepts.map { |e| e.name }
      format.json { render :json => concepts_list.to_json}      
    end
  end

  def get_concepts_list_with_id
    concepts = Topicconcept.where(course_id: @course.id, typename: "concept").select([:name, :id])
    respond_to do |format|
      format.json { render json: concepts }      
    end
  end

  def get_concept_edges_list_with_id
    concepts = @course.topicconcepts.concepts
    concept_edges = []
    concepts.each do |concept|
    	dependent_concept_edges = concept.concept_edge_dependent_concepts
    	dependent_concept_edges.each do |dependent_concept_edge|
    		concept_edges << { 
    												id: dependent_concept_edge.id, 
    						   					name: concept.name + 
    						   								" REQUIRED BY " + 
    						   								dependent_concept_edge.dependent_concept.name
    						   			 }
    	end
    end
    respond_to do |format|
      format.json { render json: concept_edges }      
    end
  end
  
  def topic_concept_data_save_dependency
    old_required_concepts = JSON.parse(params[:old_array])
    new_required_concepts = JSON.parse(params[:new_array])
    new_required_concepts.each do |obj|
      if(!old_required_concepts.include? obj)
        tc = @course.topicconcepts.where(:name => obj).first
        if(!tc.nil?)        
          concept_edge = ConceptEdge.new
          concept_edge.dependent_id = params[:id]
          concept_edge.required_id = tc.id
          concept_edge.save          
        end
      end
    end
    old_required_concepts.each do |obj|
      if(!new_required_concepts.include? obj)
        tc = @course.topicconcepts.where(:name => obj).first
        if(!tc.nil?)        
          concept_edge = ConceptEdge.find_by_dependent_id_and_required_id(params[:id],tc.id)
          if(!concept_edge.nil?)
            concept_edge.destroy
          end          
        end
      end
    end
    tcs = Topicconcept.find params[:id]
    respond_to do |format|
      format.json { render :json => tcs.required_concepts.to_json}      
    end
  end
  
  def get_topicconcept_data    
    respond_to do |format|
      @topics_concepts_with_info = []
      get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
      @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank.split('.')[e[:itc].rank.split('.').length-1].to_i}
      if can? :manage, Topicconcept
        user_ability = 'manage'
        format.json { render :json =>{:user_ability => user_ability, :topictrees => @topics_concepts_with_info}}
      else
        user_ability = 'view'
        format.json { render :json =>{:user_ability => user_ability,
                                    :topictrees => @topics_concepts_with_info,
                                    :nodelist => Topicconcept.where(:course_id => @course.id, :typename => 'concept'),
                                    :edgelist => ConceptEdge.joins("INNER JOIN topicconcepts ON topicconcepts.id = concept_edges.dependent_id").where(:topicconcepts => {:course_id => @course.id})
                                    }
                  }    
      end
    end    
  end
  
  def get_topicconcept_data_noedit
    respond_to do |format|
      @topics_concepts_with_info = []
      get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
      @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}

      format.json { render :json =>{
                                  :topictrees => @topics_concepts_with_info,
                                  :nodelist => Topicconcept.where(:course_id => @course.id, :typename => 'concept'),
                                  :edgelist => ConceptEdge.joins("INNER JOIN topicconcepts ON topicconcepts.id = concept_edges.dependent_id").where(:topicconcepts => {:course_id => @course.id})
                                  }
                }    

    end 
  end

  def get_topicconcept_rated_data
    result = {}
    result[:name] = @topicconcept.name;
    if @topicconcept.is_concept?
      user_course_id = nil
      if can? :manage, Topicconcept
        user_course_id = nil
      else    
        user_course_id = curr_user_course.id
      end

      result[:raw_right] = @topicconcept.all_raw_correct_answer_attempts(user_course_id).size
      result[:raw_total] = result[:raw_right] + @topicconcept.all_raw_wrong_answer_attempts(user_course_id).size
      latest_answers = @topicconcept.all_latest_answer_attempts(user_course_id)
      result[:latest_right] = latest_answers[:correct].size
      result[:latest_total] = latest_answers[:correct].size + latest_answers[:wrong].size
      optimistic_answers = @topicconcept.all_optimistic_answer_attempts(user_course_id)
      result[:optimistic_right] = optimistic_answers[:correct].size
      result[:optimistic_total] = optimistic_answers[:correct].size + optimistic_answers[:wrong].size
      pessimistic_answers = @topicconcept.all_pessimistic_answer_attempts(user_course_id)
      result[:pessimistic_right] = pessimistic_answers[:correct].size
      result[:pessimistic_total] = pessimistic_answers[:correct].size + pessimistic_answers[:wrong].size
    else
      result[:raw_right] = "nil"
      result[:raw_total] = "nil"
      result[:latest_right] = "nil"
      result[:latest_total] = "nil"
      result[:optimistic_right] = "nil"
      result[:optimistic_total] = "nil"
      result[:pessimistic_right] = "nil"
      result[:pessimistic_total] = "nil"
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  def get_topicconcept_overall_statistics
    result = {}
    result[:name] = @topicconcept.name;
    if @topicconcept.is_concept?

      raw_right = @topicconcept.all_raw_correct_answer_attempts_from_guidance_quiz(@guidance_quiz).size
      result[:raw_right] = raw_right
      raw_total = result[:raw_right] + @topicconcept.all_raw_wrong_answer_attempts_from_guidance_quiz(@guidance_quiz).size
      result[:raw_total] = raw_total
      result[:raw_percent] = get_percentage_string raw_right, raw_total 

      stroke_color = get_red_green_color raw_right, raw_total, 0, 140    
      result[:stroke] = "rgb("+ stroke_color[:red] +", "+ stroke_color[:green] +", 0)"
      fill_color = get_red_green_color raw_right, raw_total, 200, 55
      result[:fill] = "rgb("+ fill_color[:red] +", "+ fill_color[:green] +", 200)"

    else
      result[:raw_right] = "nil"
      result[:raw_total] = "nil"
      result[:raw_percent] = "nil"
      result[:stroke] = "rgb(70, 70, 0)"
      result[:fill] = "rgb(227, 227, 200)"
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  def get_topicconcept_single_statistics
    result = {}
    result[:name] = @topicconcept.name;

    unless params.has_key?(:submission_id)
      redirect_to course_topicconcepts_path(@course), alert: " Submission parameters not found!"
      return
    end
    @submission = load_and_authorize_submission_with_id params[:submission_id]
    #Submission not available, refer back to map
    if @submission.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Submission not found!"
      return
    end

    if @topicconcept.is_concept?

      raw_right = @topicconcept.all_raw_correct_answer_attempts_from_guidance_quiz(@guidance_quiz, @submission).size
      result[:raw_right] = raw_right
      raw_total = result[:raw_right] + @topicconcept.all_raw_wrong_answer_attempts_from_guidance_quiz(@guidance_quiz, @submission).size
      result[:raw_total] = raw_total
      result[:raw_percent] = get_percentage_string raw_right, raw_total 

      stroke_color = get_red_green_color raw_right, raw_total, 0, 140    
      result[:stroke] = "rgb("+ stroke_color[:red] +", "+ stroke_color[:green] +", 0)"
      fill_color = get_red_green_color raw_right, raw_total, 200, 55
      result[:fill] = "rgb("+ fill_color[:red] +", "+ fill_color[:green] +", 200)"

    else
      result[:raw_right] = "nil"
      result[:raw_total] = "nil"
      result[:raw_percent] = "nil"
      result[:stroke] = "rgb(70, 70, 0)"
      result[:fill] = "rgb(227, 227, 200)"
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  def get_topicconcept_single_current_statistics
    result = {}
    result[:name] = @topicconcept.name;

    unless params.has_key?(:submission_id)
      redirect_to course_topicconcepts_path(@course), alert: " Submission parameters not found!"
      return
    end
    @submission = load_and_authorize_submission_with_id params[:submission_id]
    #Submission not available, refer back to map
    if @submission.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Submission not found!"
      return
    end

    if @topicconcept.is_concept?
      concept_stage = Assessment::GuidanceConceptStage.get_stage @submission, @topicconcept
    end

    if concept_stage
      raw_right = concept_stage.total_right
      result[:raw_right] = concept_stage.total_right
      raw_total = concept_stage.total_right + concept_stage.total_wrong
      result[:raw_total] = raw_total
      result[:raw_percent] = get_percentage_string raw_right, raw_total 
    else
      result[:raw_right] = "nil"
      result[:raw_total] = "nil"
      result[:raw_percent] = "nil"
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  def get_topicconcept_best_concepts
    @submission = load_and_authorize_submission_with_id params[:submission_id]
    if @submission.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Submission not found!"
      return
    end

    concept_stages = Assessment::GuidanceConceptStage.get_stages @submission
    #concept_stages.sort_by{|cs| (cs.total_right + cs.total_wrong) == 0 ? 0 : cs.total_right * -100 / (cs.total_right + cs.total_wrong) }
    rehashed_stages = concept_stages.map{|cs| {concept: cs.concept, right: (cs.total_right + cs.total_wrong) == 0 ? 1 : cs.total_right, total: (cs.total_right + cs.total_wrong) == 0 ? 100 : (cs.total_right + cs.total_wrong)} }

    respond_to do |format|
      format.json { render json: rehashed_stages.map{|cs| {label: cs[:concept].name, value: cs[:right] * 100 / cs[:total] }}}
    end
    #respond_to do |format|
    #  format.json { render json: concept_stages.map{|cs| {label: cs.concept.name, value: (cs.total_right + cs.total_wrong) == 0 ? 0 : cs.total_right * 100 / (cs.total_right + cs.total_wrong) }}}
    #end
  end

  def get_topicconcept_notbest_concepts
    @submission = load_and_authorize_submission_with_id params[:submission_id]
    if @submission.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Submission not found!"
      return
    end

    concept_stages = Assessment::GuidanceConceptStage.get_stages @submission
    #concept_stages.sort_by{|cs| (cs.total_right + cs.total_wrong) == 0 ? 0 : cs.total_wrong * -100 / (cs.total_right + cs.total_wrong) }
    rehashed_stages = concept_stages.map{|cs| {concept: cs.concept, wrong: (cs.total_right + cs.total_wrong) == 0 ? 1 : cs.total_wrong, total: (cs.total_right + cs.total_wrong) == 0 ? 2 : (cs.total_right + cs.total_wrong)} }

    respond_to do |format|
      format.json { render json: rehashed_stages.map{|cs| {label: cs[:concept].name, value: cs[:wrong] * 100 / cs[:total] }}}
    end
    #respond_to do |format|
    #  format.json { render json: concept_stages.map{|cs| {label: cs.concept.name, value: (cs.total_right + cs.total_wrong) == 0 ? 0 : cs.total_wrong * 100 / (cs.total_right + cs.total_wrong) }}}
    #end
  end

  def get_topicconcept_weights
    result = {}

    enabled_concepts = Topicconcept.joins("INNER JOIN assessment_guidance_concept_options ON assessment_guidance_concept_options.topicconcept_id = topicconcepts.id")
                                   .concepts
                                   .where(topicconcepts: {course_id: @course.id}, assessment_guidance_concept_options: {enabled: true})

    if enabled_concepts.size > 0
      result[:concepts] = []
      enabled_concepts.each do |current_concept|
        related_stages = Assessment::GuidanceConceptStage.joins("INNER JOIN assessment_submissions ON assessment_submissions.id = assessment_guidance_concept_stages.assessment_submission_id")
                                                         .where(assessment_guidance_concept_stages: {topicconcept_id: current_concept.id, failed: false}, assessment_submissions: {status: "attempting"})
        curr_result = {
                        title: current_concept.name,
                        value: related_stages.count,
                        students: related_stages.map { |rs| { name: rs.submission.std_course.name } }
                      }

        result[:concepts] << curr_result
      end

    else
      result[:concepts] = [{title: "NONE", value: 1}]
    end
    
    respond_to do |format|
      format.json { render json: result}
    end 
  end

  def get_topicconcept_area
    enabled_concepts = Topicconcept.joins("INNER JOIN assessment_guidance_concept_options ON assessment_guidance_concept_options.topicconcept_id = topicconcepts.id")
                                   .concepts
                                   .where(topicconcepts: {course_id: @course.id}, assessment_guidance_concept_options: {enabled: true})
    #Get accumulative boolean parameter
    if params.has_key?("accumulative")
      accumulative = params[:accumulative].to_s == "true"
    else
      accumulative = false
    end

    #Get correct/wrong boolean parameter
    if params.has_key?("correct")
      correct_type = AREA_GRAPH_CORRECT_TYPE[params[:correct]]
    else
      correct_type = "nil"
    end

    #Get start period date parameter
    if params.has_key?("start_period")
      start_date = Time.parse(params[:start_period])
    else
      start_date = Time.now - 1.months
    end

    #Get end period date parameter
    if params.has_key?("end_period")
      end_date = Time.parse(params[:end_period])
    else
      end_date = Time.now
    end

    #Get tag type
    if params.has_key?("tag_id") and params[:"tag_id"] != "nil"
      tag = @course.tags.where(id: params[:"tag_id"]).first
    else
      tag = nil
    end

    #Get time step type
    if params.has_key?("time_step")
      case params[:time_step]
      when "day"
        time_step = 1.day
        time_key = "day"
      when "month"
        time_step = 1.month
        time_key = "month"
      when "year"
        time_step = 1.year
        time_key = "year"
      else
        time_step = 1.day
        time_key = "day"
      end
    else
      time_step = 1.day
      time_key = "day"
    end

    query_string = "assessment_answers.updated_at <= ? and assessment_answers.updated_at >= ? "
    query_start_date_string = "1000-01-01"
    area_data = []
    (start_date.to_i .. end_date.to_i).step(time_step) do |date_int|
      date = Time.at(date_int)
      offset_date = date + 1.day
      query_end_date_string = offset_date.strftime("%Y-%m-%d")
      solo_data = {}
      if !accumulative
        query_start_date_string = date.strftime("%Y-%m-%d")
      end

      sbms = @guidance_quiz.submissions
      if tag 
        tag_questions = tag.questions
        enabled_concepts.each do |concept|
          questions = concept.questions.where("assessment_questions.id in (?)", tag_questions)
          answer_count = 0
          questions.each do |question|
            answer_count += get_answer_count_mcq_answers_with_mcqunit question, query_string, correct_type, sbms, query_start_date_string, query_end_date_string
          end
          solo_data[concept.id.to_s] = answer_count
          solo_data[time_key] = query_end_date_string
        end
      else
        enabled_concepts.each do |concept|
          solo_data[concept.id.to_s] = get_answer_count_mcq_answers_with_mcqunit concept, query_string, correct_type, sbms, query_start_date_string, query_end_date_string
          solo_data[time_key] = query_end_date_string
        end
      end
      area_data << solo_data
    end

    respond_to do |format|
      format.json { 
        render json: {
          data: area_data,
          x: time_key,
          y: enabled_concepts.map { |ec| ec.id.to_s },
          concepts: enabled_concepts.map { |ec| ec.name }
        }
      }
      format.html {
        render locals: {
          data: area_data,
          x: time_key,
          y: enabled_concepts.map { |ec| ec.id.to_s },
          concepts: enabled_concepts.map { |ec| ec.name },

          accumulative: accumulative,
          correct: params[:correct],
          start_period: params[:start_period],
          end_period: params[:end_period],
          time_step: params[:time_step],
          current_tag: tag,
          tags: @course.tags
        }
      } 
    end
  end

  def get_progress_bar_info
    respond_to do |format|
      format.json { 
        render json: @progress_bar
      }
    end
  end

  def get_all_concepts
    respond_to do |format|
      format.json { 
        render json: {
          concepts: @course.topicconcepts.concepts
        }
      }
    end
  end

  #Get the edges from a concept where it is the dependent party
  def get_concept_required_edges
    concept = @course.topicconcepts.concepts.where(id: params[:id]).first
    if !concept.nil?
      required_concept_edges = concept.concept_edge_required_concepts
      respond_to do |format|
        format.json { render :json => { :current_concept => concept, :dependencies => required_concept_edges.map { |e| { concept_edge_id: e.id, required_concept_name: e.required_concept.name} }}}      
      end
    else
      raise "Concept id is invalid"
    end
  end

	def set_student_layout
		if cannot? :manage, Topicconcept or @student_view
      self.class.layout "topicconcept_student_interface"
    else
      self.class.layout "application"
    end
  end

  def set_student_view
    session[:topicconcept_student_view] = !params[:student_view].nil? and params[:student_view] == "true"
    @student_view = session[:topicconcept_student_view]
  end

  def set_hidden_sidebar_params
    @hidden = !params[:hideSideBar].nil? and params[:hideSideBar] == "true"
  end

  #Set viewing permission and parameters of user
  def set_viewing_permissions
    @gqEnabled = Assessment::GuidanceQuiz.is_enabled? (@course)
    if @gqEnabled
      set_student_view
      set_student_layout
      set_hidden_sidebar_params
    end
  end

  #Get red green color representations based on input parameter percentages
  def get_red_green_color current = 0, total = 0, offset = 0, size = 0
    red = 0
    green = 0

    if total <= 0
      red = offset + size / 2
      green = offset + size / 2
    else
      itmd = current * 1.0 / total
      green = itmd * size + offset
      red = (1 - itmd) * size + offset
    end

    {
      red: red.ceil.to_s,
      green: green.ceil.to_s
    }
  end

  #Return the true percentage string representation of the input parameters
  def get_percentage_string current = 0, total = 0
    result = "0"
    if total <= 0
      result = "NaN"
    else
      itmd = current * 100 / total
      result = itmd.to_s + "%"
    end


    result
  end

private
  AREA_GRAPH_CORRECT_TYPE = {
                              "wrong" => 0,
                              "correct" => 1,
                              "absolute" => 2,
                              "both" => 3
                            }

  def get_answer_count_mcq_answers_with_mcqunit mcqunit, additional_query_string, correct_type, submissions, start_date, end_date
    result = 0
    case correct_type
    when AREA_GRAPH_CORRECT_TYPE["wrong"]
      result = mcqunit.mcq_answers
                      .where("assessment_answers.correct = '0' AND assessment_answers.submission_id IN (?) AND " + additional_query_string , 
                              submissions,
                              end_date,
                              start_date).count
    when AREA_GRAPH_CORRECT_TYPE["absolute"]
      result = mcqunit.mcq_answers
                      .where("assessment_answers.correct = '1' AND assessment_answers.submission_id IN (?) AND " + additional_query_string , 
                              submissions,
                              end_date,
                              start_date).count
      result -= mcqunit.mcq_answers
                      .where("assessment_answers.correct = '0' AND assessment_answers.submission_id IN (?) AND " + additional_query_string , 
                              submissions,
                              end_date,
                              start_date).count
    when AREA_GRAPH_CORRECT_TYPE["both"]
      result = mcqunit.mcq_answers
                      .where("assessment_answers.submission_id IN (?) AND " + additional_query_string , 
                              submissions,
                              end_date,
                              start_date).count
    else
      result = mcqunit.mcq_answers
                      .where("assessment_answers.correct = '1' AND assessment_answers.submission_id IN (?) AND " + additional_query_string , 
                              submissions,
                              end_date,
                              start_date).count
    end

    result
  end

  def authorize_and_load_guidance_quiz
    #No start time for guidance quiz, only can start after published
    unless Assessment::GuidanceQuiz.is_enabled? @course
      redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!"
      return
    end

    @guidance_quiz = @course.guidance_quizzes.first
  end 

  def authorize_and_load_guidance_quiz_and_submission_and_concept_for_review
    #No start time for guidance quiz, only can start after published
    unless Assessment::GuidanceQuiz.is_enabled? @course
      redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!"
      return
    end

    @guidance_quiz = @course.guidance_quizzes.first
    @submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id,
                                                   status: "attempting").first
    data_synchronise_submission @submission

    if @submission
      @concept_stage = Assessment::GuidanceConceptStage.get_latest_passed_stage @submission
      if @concept_stage
        @latest_concept = @concept_stage.concept
      end
    end

    @latest_submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id).order("created_at DESC").first
    if @latest_submission.nil?
      redirect_to course_topicconcepts_path(@course), alert: " Choose concept first!"
      return
    else
      data_synchronise_submission @latest_submission
    end
  end

  def authorize_and_load_guidance_quiz_and_submission_and_concept_for_index
    #No start time for guidance quiz, only can start after published
    #This is for retrieving the latest concept attempted
    if Assessment::GuidanceQuiz.is_enabled? @course
      @guidance_quiz = @course.guidance_quizzes.first
      @submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id,
                                                   status: "attempting").first
      if @submission
        data_synchronise_submission @submission
        @concept_stage = Assessment::GuidanceConceptStage.get_latest_passed_stage @submission
        if @concept_stage
          @latest_concept = @concept_stage.concept
        end
      end

      @latest_submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id).first
      data_synchronise_submission @latest_submission
    end
  end

  def authorize_and_load_guidance_quiz_and_submission_and_concept_and_conceptstage
    #No start time for guidance quiz, only can start after published
    unless Assessment::GuidanceQuiz.is_enabled? @course
      redirect_to course_topicconcepts_path(@course), alert: " Not opened yet!"
      return
    end

    @guidance_quiz = @course.guidance_quizzes.first
    @assessment = @guidance_quiz.assessment
    @submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id,
                                                   status: "attempting").first
    data_synchronise_submission @submission

    #Submission not available, refer back to map
    if @submission.nil? or !@submission.attempting?
      redirect_to course_topicconcepts_path(@course), alert: " Choose concept first!"
      return
    end
    @latest_submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id).first
    data_synchronise_submission @latest_submission

    unless @topicconcept.is_concept?
      redirect_to course_topicconcepts_path(@course), alert: " This is not a concept!"
      return
    end

    @concept = @topicconcept
    @concept_stage = Assessment::GuidanceConceptStage.get_passed_stage @submission, @concept

    unless @concept_stage
      redirect_to course_topicconcepts_path(@course), alert: " Choose concept first!"
      return
    end

    @latest_concept = @concept
  end

  def load_general_topicconcept_data
    @user_course = curr_user_course

    @guidance_quiz = @course.guidance_quizzes.first
    @submission = @guidance_quiz.submissions.where(std_course_id: curr_user_course.id,
                                                 status: "attempting").first
    data_synchronise_submission @submission

    #Submission not available, indicate progress bar as such
    if @submission.nil? or !@submission.attempting?
      @progress_bar = {
                        pass: 0,
                        fail: 0,
                        enable: 0,
                        disable: 100,
                        pass_amt: 0,
                        fail_amt: 0,
                        enable_amt: 0,
                        disable_amt: 0,
                        disable_message: "Assessment not started yet"
                      }
    else
      passed_concept_stages = Assessment::GuidanceConceptStage.get_passed_stages @submission
      passed_concepts = passed_concept_stages.collect(&:concept).uniq
      failed_concept_stages = Assessment::GuidanceConceptStage.get_failed_stages @submission
      failed_concepts = failed_concept_stages.collect(&:concept).uniq
      enabled_concepts = Topicconcept.joins("INNER JOIN assessment_guidance_concept_options ON assessment_guidance_concept_options.topicconcept_id = topicconcepts.id")
                                      .concepts
                                      .where(topicconcepts: {course_id: @course.id}, assessment_guidance_concept_options: {enabled: true})
      all_concepts = @course.topicconcepts.concepts 

      passed_concept_count = passed_concepts.count
      failed_concept_count = failed_concepts.count
      disabled_concept_count = all_concepts.count - enabled_concepts.count
      enabled_concept_count = enabled_concepts.count - passed_concept_count - failed_concept_count 
      total = passed_concept_count + failed_concept_count + disabled_concept_count + enabled_concept_count
      @progress_bar = {
                        pass: passed_concept_count * 100.0 / total,
                        fail: failed_concept_count * 100.0 / total,
                        enable: enabled_concept_count * 100.0 / total,
                        disable: disabled_concept_count * 100.0 / total,
                        pass_amt: passed_concept_count,
                        fail_amt: failed_concept_count,
                        enable_amt: enabled_concept_count,
                        disable_amt: disabled_concept_count,
                      }
    end
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

  def set_topicconcept_updated_timing
    @course.topicconcepts_updated_timing_singleton.set_updated_timing
  end

  def set_popup_layout
    self.class.layout "topicconcept_trend_popup"
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
