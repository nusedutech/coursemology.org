class Assessment::QuestionsController < ApplicationController
  load_and_authorize_resource :course
  load_resource :assessment, through: :course

  before_filter :build_resource
  before_filter :extract_tags, only: [:update]
  before_filter :load_general_course_data, only: [:index, :new, :edit,:show, :add_question]

  def index
    authorize! :manage, Course
    filter = params[:tags]
    #search_string = params[:search_string]
    questions = nil

=begin
    if (!filter.nil? && !filter.empty?)
      filter_tags = filter.split(",")
      q = ''
      if filter_tags.count > 0
        @summary = {selected_tags: filter_tags || []}
        filter_tags.each do |t|
          q += q.empty? ? "topicconcepts.name = '#{t}'" : " or topicconcepts.name = '#{t}'"
        end
      end

      if !search_string.empty?
        @questions = @course.questions.where(q).where("assessment_questions.title like ? or assessment_questions.description like ?", "%#{search_string}%", "%#{search_string}%").uniq
      else
        @questions = @course.questions.where(q).uniq
      end
    elsif (!search_string.nil? && !search_string.empty?)
      @questions = @course.questions.where("assessment_questions.title like ? or assessment_questions.description like ?", "%#{search_string}%", "%#{search_string}%").uniq
    else
      @questions = @course.questions.uniq
    end
=end    

    respond_to do |format|
      format.json { render json: @course.topicconcepts.concepts.map {|t| {id: t.id, name: t.name }} + @course.tags.map {|t| {id: t.id, name: t.name }}}
      format.html
    end
  end
  
  def add_question
    filter = params[:tags]
    search_string = ""
    search_string = params[:search_string]
    query_string = "assessment_questions.title like '%#{search_string}%' or assessment_questions.description like '%#{search_string}%'"

    questions = []
    assessment_based_questions = [];
    #filter question by kind of assessment
    if @assessment.is_mission?
      assessment_based_questions = @course.questions.general_and_coding_question
    elsif @assessment.is_training?
      assessment_based_questions = @course.questions.mcq_and_coding_question
    elsif @assessment.is_policy_mission?
      assessment_based_questions = @course.questions.mcq_question
    end

    if !assessment_based_questions.empty?
      if !filter.nil? and !filter.empty?
        filter_tags = filter.split(",")
        if filter_tags.count > 0
          @summary = {selected_tags: filter_tags || []}

          tag_query_string = ""
          filter_tags.each do |t|
            tag_query_string += tag_query_string.empty? ? "tags.name = '#{t}'" : " or tags.name = '#{t}'"
          end
          selected_tags =  @course.tags.where(tag_query_string)

          topicconcepts_query_string = ""
          filter_tags.each do |t|
            topicconcepts_query_string += topicconcepts_query_string.empty? ? "topicconcepts.name = '#{t}'" : " or topicconcepts.name = '#{t}'"
          end
          selected_topicconcepts =  @course.topicconcepts.concepts.where(topicconcepts_query_string)

          selected_taggable_tags = []
          selected_tags.each do |tag|
            selected_taggable_tags = selected_taggable_tags + tag.taggable_tags
          end
          selected_topicconcepts.each do |topicconcept|
            selected_taggable_tags = selected_taggable_tags + topicconcept.taggable_tags
          end
          selected_taggable_tags = selected_taggable_tags.uniq

          #Link broken for question to taggable_tag - temp fix
          selected_taggable_tags.each do |taggable_tag|
            questions = questions + assessment_based_questions.where(query_string + " and assessment_questions.id = ? ", taggable_tag.taggable_id)
          end
        end
      else
        questions = questions + assessment_based_questions.where(query_string)
      end

      if questions.count > 0
        #Add questions in the assessment already to filter criteria
        questions = questions + @assessment.questions
        @questions = questions.uniq
      else
        @questions = assessment_based_questions
      end
    else
      @questions = []
    end
  end

  def import
    respond_to do |format|
      result = Assessment::Question.import(params[:file], current_user, @course)
      if result[:flag]
        format.html { redirect_to main_app.course_assessment_questions_url(@course),
                                notice: result[:info] }
      else
        format.html { redirect_to main_app.course_assessment_questions_url(@course),
                                  :flash => { :error => result[:info] }}
      end
    end
  end

  def edit
    if !params[:assessment_mpq_question_id].nil?
      @parent_mpq_question = Assessment::MpqQuestion.find_by_id(params[:assessment_mpq_question_id])
    end
    @tags_list = {}
    @tags_list[:concept] = {:origin => @question.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}
    @course.tag_groups.each do |t|
      @tags_list[t.name] = {:origin => @question.tags.where(:tag_group_id => t.id).select(:name).map { |e| e.name }, :all => Tag.where(:tag_group_id => t.id).select(:name).map { |e| e.name }}
    end

  end
  
  def new
    if !params[:assessment_mpq_question_id].nil?
      @parent_mpq_question = Assessment::MpqQuestion.find_by_id(params[:assessment_mpq_question_id])
    end
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
    @question.course = @course
    @question.save
    if !params[:parent_mpq_question].nil?
      @parent_mpq_question = Assessment::MpqQuestion.find_by_id(params[:parent_mpq_question])
      sq = @parent_mpq_question.children.new
      sq.child_id = @question.question.id
      sq.save
    end
    if !@assessment.nil?
      qa = @assessment.question_assessments.new
      qa.question = @question.question
      qa.position = @assessment.questions.count
      qa.save
    end
    #@question.save && qa.save
  end

  def update
    if !params[:parent_mpq_question].nil?
      @parent_mpq_question = Assessment::MpqQuestion.find_by_id(params[:parent_mpq_question])
    end
  end

  def destroy
    if !@assessment.nil?
      qa = QuestionAssessment.find_by_assessment_id_and_question_id(@assessment.id, @question.question.id)
      if !qa.nil?
        qa.destroy
      end
    else
      @question.destroy
    end
    respond_to do |format|
      if !@assessment.nil?
        format.html { redirect_to url_for([@course, @assessment.as_assessment]),
                                notice: "Question has been successfully deleted." }
      else
        format.html { redirect_to main_app.course_assessment_questions_url(@course),
                                  notice: "Question has been successfully deleted." }
      end
    end
  end

  def download_import_question_template
    send_file "#{Rails.root}/public/import-question-template.csv",
              :filename => "import-question-template.csv",
              :type => "application/csv"
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
