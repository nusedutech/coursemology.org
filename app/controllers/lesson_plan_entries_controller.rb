class LessonPlanEntriesController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :lesson_plan_entry, through: :course

  before_filter :load_general_course_data, :only => [:index, :new, :edit, :overview, :submission]


  def index
    @milestones = LessonPlanEntry.get_milestones_for_course(@course, current_ability, (can? :manage, Assessment::Mission), @curr_user_course)
    @current_id = params["eid"].nil? ? '' : params["eid"]
    if (session["ivle_login_data"] && @course.module_id)
      @ivle_token = session["ivle_login_data"].credentials.token
      @ivle_api = Rails.application.config.ivle_api_key
      @mapping_module = @course.module_id
    end
  end

  def import_ivle_event
    event_list = []
    if params["ivle_event"]["choose"]
      params["ivle_event"]["choose"].each do |e|
        if (params["ivle_event"]["week_text"][e] && params["ivle_event"]["week_text"][e].downcase == 'every week')
          #save student group
          group = @course.student_groups.where(:name => e.to_s).first
          if !group
            group = @course.student_groups.new(:name => e.to_s)
            group.save
          end

          #save lesson_plan_entities
          milestones = @course.lesson_plan_milestones.where("title <> ? and title <> ? and title <> ?","Recess Week", "Reading Week", "Examination Week")
          milestones.each do |m|
            start_day = m.start_at.to_date
            end_day = m.end_at.to_date
            my_days = [params["ivle_event"]["day_code"][e]] # day of the week in 0-6. Sunday is day-of-week 0; Saturday is day-of-week 6.
            result = (start_day..end_day).to_a.select {|k| my_days.include?(k.wday.to_s)}
            result.each_with_index do |d, index|
              entry = LessonPlanEntry.new
              entry.course = @course
              entry.creator = current_user
              entry.group = group
              entry.title = params["ivle_event"]["lesson_type"][e].downcase.capitalize + ' - ' + 'Group ' + e.to_s
              lesson_type = params["ivle_event"]["lesson_type"][e].downcase
              entry.entry_type = lesson_type == 'lecture' ? 0 : (lesson_type == 'recitation' ? 1 : (lesson_type == 'tutorial' ? 2 : 4))
              start_time = params["ivle_event"]["start_time"][e]
              end_time = params["ivle_event"]["end_time"][e]
              entry.start_at = DateTime.parse( "#{d} #{start_time[0..start_time.length-3]}:#{start_time[start_time.length-2..start_time.length-1]} +0800" )
              entry.end_at = DateTime.parse( "#{d} #{end_time[0..end_time.length-3]}:#{end_time[end_time.length-2..end_time.length-1]} +0800" )
              entry.location = params["ivle_event"]["venue"][e]
              entry.description = ''
              entry.save
            end
          end
        else

        end
      end

      respond_to do |format|
       format.html { redirect_to course_lesson_plan_path(@course), notice: "Import IVLE events successfully." }
      end
    else
      respond_to do |format|
        format.html { redirect_to course_lesson_plan_path(@course) }
      end
    end

  end

  def submission
    #old version
    #@milestones = get_milestones_for_course(@course)
    #@current_id = @assessment.nil? ? '0' : "virtual-entity-#{@assessment.id}"
    #@is_lesson_plan_submission = true
    #@mission_show = params['show']
    #@discuss = params['discuss']

    #call new method of Submission
    @assessment = Assessment.find_by_id(params['assessment_id'])
    redirect_to new_course_assessment_submission_path(@course,
                                                      @assessment,
                                                      :from_lesson_plan => true,
                                                      :discuss => params['discuss']
                )
  end

  def mission_update
    @assessment = Assessment.find_by_id(params['assessment_id'])
    @submission = @assessment.submissions.where(std_course_id: curr_user_course).last
    @submission.fetch_params_answers(params)
    if params[:files]
      @submission.attach_files(params[:files].values)
    end

    respond_to do |format|
      if @submission.save
        if params[:commit] == 'Save'
          @submission.set_attempting
          #course_lesson_plan_submission_path(@course, @assessment, anchor: 'training-stop-pos', step: @summary[:step] + 1)
          format.html { redirect_to course_lesson_plan_submission_path(@course, @assessment),
                                    notice: "Your submission has been saved." }
        else
          @submission.set_submitted
          format.html { redirect_to course_lesson_plan_submission_path(@course, @assessment, show: true),
                                    notice: "Your submission has been updated." }
        end
      else
        format.html { render action: "edit" }
      end
    end
  end

  def new
    if (session["ivle_login_data"] && @course.module_id)
      @ivle_token = session["ivle_login_data"].credentials.token
      @ivle_api = Rails.application.config.ivle_api_key
      @mapping_module = @course.module_id
    end

    @tags_list = {:origin => @lesson_plan_entry.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}

    @start_at = params[:start_at] || ""
    @end_at = params[:end_at] || ""

    @start_at = (DateTime.strptime(@start_at, '%d-%m-%Y') unless @start_at.empty?)
    @end_at = (DateTime.strptime(@end_at, '%d-%m-%Y') unless @end_at.empty?)
  end

  def create
    @lesson_plan_entry.creator = current_user
    @lesson_plan_entry.resources = if params[:resources] then
                                     build_resources(params[:resources])
                                   else
                                     []
                                   end

    #add tags
    if (!params["new_tags"].nil? && !params["original_tags"].nil?)
      if(params["new_tags"] != params["original_tags"])
        update_tag(JSON.parse(params["original_tags"]),JSON.parse(params["new_tags"]), nil)
      end
    end

    respond_to do |format|
      if @lesson_plan_entry.save then
        path = course_lesson_plan_path(@course) + "#entry-" + @lesson_plan_entry.id.to_s
        format.html { redirect_to path,
                      notice: "The lesson plan entry #{@lesson_plan_entry.title} has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def edit
    @tags_list = {:origin => @lesson_plan_entry.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}

  end

  def update
    @lesson_plan_entry.resources = if params[:resources] then
                                     build_resources(params[:resources])
                                   else
                                     []
                                   end

    #add tags
    if (!params["new_tags"].nil? && !params["original_tags"].nil?)
      if(params["new_tags"] != params["original_tags"])
        update_tag(JSON.parse(params["original_tags"]),JSON.parse(params["new_tags"]), nil)
      end
    end

    respond_to do |format|
      if @lesson_plan_entry.update_attributes(params[:lesson_plan_entry]) && @lesson_plan_entry.save then
        path = course_lesson_plan_path(@course) + "#entry-" + @lesson_plan_entry.id.to_s
        format.html { redirect_to path,
                      notice: "The lesson plan entry #{@lesson_plan_entry.title} has been updated." }
      else
        format.html { render action: "index" }
      end
    end
  end

  def destroy
    @lesson_plan_entry.destroy
    respond_to do |format|
      format.html { redirect_to :back,
                    notice: "The lesson plan entry #{@lesson_plan_entry.title} has been removed." }
    end
  end

  def overview
    @milestones = get_milestones_for_course(@course)
    render "/lesson_plan/overview"
  end

private
  def render(*args)
    options = args.extract_options!
    options[:template] = "/lesson_plan/#{options[:action] || params[:action]}"
    super(*(args << options))
  end

  # Builds the resource array to be assigned to a model from form parameters
  def build_resources(param)
    resources = []
    param.each { |r|
      obj_parts = r.split(',')
      res = LessonPlanResource.new
      res.obj_id = obj_parts[0]
      res.obj_type = obj_parts[1]
      resources.push(res)
    }

    resources
  end

  def update_tag(original_tags, new_tags, group)
    new_tags.each do |obj|
      if(!original_tags.include? obj)
        tag_element = @course.topicconcepts.where(:name => obj).first
        if(!tag_element.nil?)
          taggable = @lesson_plan_entry.taggable_tags.new
          taggable.tag = tag_element
          taggable.save
        end
      end
    end

    original_tags.each do |obj|
      if(!new_tags.include? obj)
        tag_element = @course.topicconcepts.where(:name => obj).first
        if(!tag_element.nil?)
          taggable = @lesson_plan_entry.taggable_tags.where(:tag_type => 'Topicconcept', :tag_id => tag_element.id).first
          if(!taggable.nil?)
            taggable.destroy
          end
        end
      end
    end
  end
end
