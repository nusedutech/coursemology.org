class TopicconceptsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :topicconcept, through: :course

  before_filter :load_general_course_data, only: [:index, :concept_questions, :get_topicconcept_rated_data]

	before_filter :set_viewing_permissions, only:[:index]

  def index   
    @topics_concepts_with_info = []
    get_topic_tree(nil, Topicconcept.where(:course_id => @course.id, :typename => 'topic'))       
    @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}

    @user_course = curr_user_course
    Rails.cache.clear
  end
  
  def ivleapi   
    
  end
  
  def master
      @concept = Topicconcept.find(params[:topicconcept_id])
      @dependencies = @concept.required_concepts
      @current_dependency = @dependencies.first
      @firstquestion = @current_dependency.questions.where(:as_question_type => Assessment::McqQuestion).first
      @select_all = false #raw_query_get_select_all(@firstquestion.as_question_id).to_i == 0 ? false : true      
      
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
    if params[:old_parent]
      old_edge = TopicEdge.find_by_parent_id_and_included_topic_concept_id(params[:old_parent],params[:id])
    end
    if params[:parent]
      new_edge = TopicEdge.new
      new_edge.parent_id = params[:parent]
      new_edge.included_topic_concept_id = params[:id]
      pc = Topicconcept.find(params[:parent])
      if pc.included_topicconcepts.count > 0 && params[:pos].to_i < pc.included_topicconcepts.count
        children_list = pc.included_topicconcepts.sort_by{|e| e.rank}
        add_level = 0
        children_list.each_with_index do |pitc, index|          
          if params[:pos].to_i == index
            tc.rank = pc.rank + '.' + (params[:pos].to_i + 1).to_s
            pitc.rank = pc.rank + '.' + (index + 2).to_s
            pitc.save
            add_level += 1
          else
            pitc.rank = pc.rank + '.' + (index + add_level + 1).to_s
            pitc.save
          end
        end
      else
        tc.rank = pc.rank + '.' + (params[:pos].to_i + 1).to_s
      end
              
    else
      tc.rank = (Topicconcept.where(:course_id => @course.id,:typename => 'topic').count + 1).to_s
    end
    
    flag = true
    respond_to do |format|
      if !old_edge.nil?
        if !old_edge.destroy
          flag = false           
        end
      end
      if !new_edge.included_topic_concept_id.nil?
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
  
  def topic_concept_data_save_dependency
    old_required_concepts = JSON.parse(params[:old_array])
    new_required_concepts = JSON.parse(params[:new_array])
    new_required_concepts.each do |obj|
      if(!old_required_concepts.include? obj)
        tc = Topicconcept.where(:name => obj).first 
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
        tc = Topicconcept.where(:name => obj).first 
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
      @topics_concepts_with_info = @topics_concepts_with_info.uniq.sort_by{|e| e[:itc].rank}
      if can? :manage, Topicconcept and !session[:topicconcept_student_view]
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
  
  def get_topicconcept_rated_data
    result = {}
    result[:name] = @topicconcept.name;
    if @topicconcept.is_concept?
      result[:raw_right] = @topicconcept.all_raw_correct_answer_attempts(curr_user_course.id).size
      result[:raw_total] = @topicconcept.all_raw_wrong_answer_attempts(curr_user_course.id).size
      latest_answers = @topicconcept.all_latest_answer_attempts(curr_user_course.id)
      result[:latest_right] = latest_answers[:correct].size
      result[:latest_total] = latest_answers[:correct].size + latest_answers[:wrong].size
      optimistic_answers = @topicconcept.all_optimistic_answer_attempts(curr_user_course.id)
      result[:optimistic_right] = optimistic_answers[:correct].size
      result[:optimistic_total] = optimistic_answers[:correct].size + optimistic_answers[:wrong].size
      pessimistic_answers = @topicconcept.all_pessimistic_answer_attempts(curr_user_course.id)
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
    set_student_view
    @gqEnabled = Assessment::GuidanceQuiz.is_enabled? (@course)
    if @gqEnabled
      set_student_layout
      set_hidden_sidebar_params
    end
  end
end
