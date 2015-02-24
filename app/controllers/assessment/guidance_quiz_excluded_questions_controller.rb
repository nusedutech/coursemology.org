class Assessment::GuidanceQuizExcludedQuestionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :question, class: "Assessment::Question", through: :course
  load_and_authorize_resource :excluded_question, class: "Assessment::GuidanceQuizExcludedQuestion", through: :question
  before_filter :load_general_course_data, only: [:exclude_questions, :update_questions]

  def get_tags
    authorize! :manage, Course

    respond_to do |format|
      format.json { render json: @course.topicconcepts.concepts.map {|t| {id: t.id, name: t.name }} + @course.tags.map {|t| {id: t.id, name: t.name }}}
    end
  end


  def exclude_questions
    authorize! :manage, Course

    filter = params[:tags]
    search_string = ""
    search_string = params[:search_string]
    query_string = "assessment_questions.title like '%#{search_string}%' or assessment_questions.description like '%#{search_string}%'"

    questions = []
    @excluded_questions = Assessment::GuidanceQuizExcludedQuestion.excluded_questions(@course)
    assessment_based_questions = Assessment::GuidanceQuizExcludedQuestion.included_questions(@course)
    @questions = []

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
        @questions = questions.uniq
        paging_setup
      end
    end
  end

  def paging_setup
    @qn_paging = @course.paging_pref('Questions')
    @qn_paging_index_offset = 0;
    if @qn_paging.display?
      pageNum = (params.has_key?(:page) && (params[:page] =~ /^\d+$/)) ? params[:page].to_i : 1
      @questions = Kaminari.paginate_array(@questions).page(pageNum).per(@qn_paging.prefer_value.to_i)
      @qn_paging_index_offset = @qn_paging.prefer_value.to_i * (pageNum-1)
    end
  end

  def update_questions
    notice = ""
    if !params[:gq].nil?
      ques_list = params[:gq][:exclusion]
    else
      ques_list = []
    end

    if (!ques_list.nil?)
      old_list = @course.exclusion_statuses
      old_list.each do |st|
        st.cur_including
      end
      ques_list.each do |q|
        next if @course.questions.where(id: q).count === 0
        question = @course.questions.where(id: q).first
        Assessment::GuidanceQuizExcludedQuestion.excluding(question)          
      end   
    end

    respond_to do |format|      
        format.html {redirect_to exclude_questions_course_assessment_guidance_quiz_excluded_questions_path(@course) }
    end 
  end

  def access_denied

  end
end
