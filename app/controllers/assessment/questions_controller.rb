class Assessment::QuestionsController < ApplicationController
  load_and_authorize_resource :course
  load_resource :assessment, through: :course
  before_filter :build_resource
  before_filter :extract_tags, only: [:update]
  before_filter :load_general_course_data, only: [:index, :new, :edit, :add_questions]

  def index
    filter = params[:tags]
    questions = []
    if !filter.nil?
      filter_tags = filter.split(",")      
      if filter_tags.count > 0
        @summary = {selected_tags: filter_tags || []}
        filter_tags.each do |t|
          @tag = @course.topicconcepts.where(:name => t).first
          if !@tag.nil?
            questions += @tag.questions
          end
        end
      end
    end
    if questions.count > 0
      @questions = questions.uniq
    else
      @questions = @course.tagged_questions.uniq
    end
    
    respond_to do |format|
      format.json { render json: @course.topicconcepts.concepts.map {|t| {id: t.id, name: t.name }}}
      format.html
    end
  end
  
  def add_question
    filter = params[:tags]
    questions = []
    if !filter.nil?
      filter_tags = filter.split(",")      
      if filter_tags.count > 0
        @summary = {selected_tags: filter_tags || []}
        filter_tags.each do |t|
          @tag = @course.topicconcepts.where(:name => t).first
          if !@tag.nil?
            questions += @tag.questions
          end
        end
      end
    end
    if questions.count > 0
      @questions = questions.uniq
    else
      @questions = @course.tagged_questions.uniq
    end
  end
  
  def edit    
    @tags_list = {}
    @tags_list[:concept] = {:origin => @question.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}
    @course.tag_groups.each do |t|
      @tags_list[t.name] = {:origin => @question.tags.where(:tag_group_id => t.id).select(:name).map { |e| e.name }, :all => Tag.where(:tag_group_id => t.id).select(:name).map { |e| e.name }}
    end

  end
  
  def new
    @tags_list = {}
    @tags_list[:concept] = {:origin => @question.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}
    @course.tag_groups.each do |t|
      @tags_list[t.name] = {:origin => @question.tags.where(:tag_group_id => t.id).select(:name).map { |e| e.name }, :all => Tag.where(:tag_group_id => t.id).select(:name).map { |e| e.name }}
    end
    
    
    #@question.max_grade = @assessment.is_mission? ? 10 : 2
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @question }
    end
  end

  def create
    @question.creator = current_user
    @question.save
    if !@assessment.nil?
      qa = @assessment.question_assessments.new
      qa.question = @question.question
      qa.position = @assessment.questions.count
      qa.save
    end
    #@question.save && qa.save
  end

  def update

  end

  def destroy
    @question.destroy
    respond_to do |format|
      format.html { redirect_to url_for([@course, @assessment.as_assessment]),
                                notice: "Question has been successfully deleted." }
    end
  end

  protected

  def extract_tags
    tags = (params[params[:controller].gsub('/', '_').singularize] || {}).delete(:tags) || ""
    tt = @course.tags.find_or_create_all_with_like_by_name(tags.split(","))
    #@question.tags = tt
  end

  def build_resource
    resource = params[:controller].classify.constantize
    if params[:id]
      @question = resource.send(:find, params[:id])
    elsif params[:action] == 'index'
      @questions = resource.accessible_by(current_ability)
    else
      @question = resource.new
      extract_tags
      (params[resource.to_s.underscore.gsub('/', '_')] || {}).each do |key, value|
        @question.send("#{key}=", value)
      end
    end
  end
end