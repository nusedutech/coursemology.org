class Assessment::AssessmentsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :assessment, only: [:reorder, :stats, :access_denied]
  before_filter :load_general_course_data, only: [:show, :index, :new, :edit, :access_denied, :stats, :overview, :listall]

  def index
    assessment_type = params[:type]
    selected_tags = params[:tags]

    display_columns = {}
    time_format =  @course.time_format(assessment_type)
    paging = @course.paging_pref(assessment_type)
    @course.assessment_columns(assessment_type, true).each do |cp|
      display_columns[cp.preferable_item.name] = cp.prefer_value
    end

    @assessments = @course.assessments.send(assessment_type)

    if selected_tags
      selected_tags = selected_tags.split(",")
      @assessments = @course.questions.tagged_with(@course.tags.named_any(selected_tags).all, any: true).assessments.send(assessment_type)
    end

    #TODO: refactoring
    if assessment_type == 'training' || assessment_type == 'policy_mission' || assessment_type == 'realtime_training' || assessment_type == 'realtime_session_group'
      @tabs = @course.tabs.training
      @tab_id = params['_tab']

      if params['_tab'] and (@tab = @course.tabs.where(id:@tab_id).first)
        @assessments = @tab.assessments
      elsif @tabs.length > 0
        @tab_id = @tabs.first.id.to_s
        @assessments= @tabs.first.assessments
      elsif assessment_type == 'policy_mission'
        @tab_id='Policy Missions'
      elsif params['_tab'] and params['_tab'] == 'Tests'
        @tab_id = params['_tab']
        @assessments = @assessments.test
      elsif assessment_type == 'realtime_training'
        @tab_id='Realtime Trainings'
      elsif assessment_type == 'realtime_session_group'
        @tab_id='Realtime Session Groups'
        assessment_id_list = []
        @assessments.each do |a|
          assessment_id_list << a.training.assessment.id if a.training
          assessment_id_list << a.mission.assessment.id if a.mission
        end
      else
        @tab_id = 'Trainings'
        @assessments = curr_user_course.is_student? ? @assessments.retry_training_without_realtime : @assessments.retry_training
      end
    else
      @assessments = @assessments.mission_without_realtime if assessment_type== 'mission' and curr_user_course.is_student?
    end
    @assessments = @assessments.includes(:as_assessment)

    if paging.display?
      @assessments = @assessments.accessible_by(current_ability).page(params[:page]).per(paging.prefer_value.to_i)
    else
      @assessments = @assessments.accessible_by(current_ability)
    end


    submissions = @course.submissions.where(assessment_id: (assessment_type == 'realtime_session_group') ? assessment_id_list : @assessments.map { |m| m.id },
                                            std_course_id: curr_user_course.id)

    sub_ids = submissions.map {|s| s.assessment_id}
    sub_map = {}
    #Going by date, the last submission will overwrite everything else
    submissions.each do |sub|
      sub_map[sub.assessment_id] = sub
    end

    #TODO:bug fix for training action, it's rather complicated
    action_map = {}
    if assessment_type == 'policy_mission'
      @listed_tags = {}
    end
    @assessments.each do |ast|
      if sub_ids.include? ast.id
        attempting = sub_map[ast.id].attempting?
        action_map[ast.id] = {}
        if !attempting
          action_map[ast.id][:action] = "Review"
          action_map[ast.id][:url] = course_assessment_submission_path(@course, ast, sub_map[ast.id])
          #Ensure controls are not revealed when assessment has ended
        elsif ast.can_access_with_end_check? (curr_user_course)
          action_map[ast.id][:action] = "Resume"
          action_map[ast.id][:url] = edit_course_assessment_submission_path(@course, ast, sub_map[ast.id])
        elsif ast.submissions.submitted_format.where(std_course_id: curr_user_course.id).first
          sub_map[ast.id] = ast.submissions.submitted_format.where(std_course_id: curr_user_course.id).first
          action_map[ast.id][:action] = "Review"
          action_map[ast.id][:url] = course_assessment_submission_path(@course, ast, sub_map[ast.id])
        end

        if ast.is_policy_mission? and !attempting and ast.specific.multipleAttempts? and ast.can_access_with_end_check? (curr_user_course)
          action_map[ast.id][:actionSecondary] = "Reattempt"
          action_map[ast.id][:urlSecondary] = reattempt_course_assessment_submissions_path(@course, ast)
        end

        if ast.is_policy_mission?
          @listed_tags[ast.id] = sub_map[ast.id].getHighestProgressionGroupLevelName
        end

        #potential bug
        #1, can mange, 2, opened and fulfil the dependency requirements
      elsif ((ast.opened? and (ast.as_assessment.class == Assessment::Training or
          ast.as_assessment.class == Assessment::RealtimeSessionGroup or
          ast.dependent_id.nil? or ast.dependent_id == 0 or
          (sub_ids.include? ast.dependent_id and !sub_map[ast.dependent_id].attempting?))) or can?(:manage, ast)) and
          (ast.can_access_with_end_check? (curr_user_course) or ast.as_assessment.class == Assessment::RealtimeSessionGroup)

          #Check student's realtime_session status
          if curr_user_course.is_student? and ast.is_realtime_session_group?
            if curr_user_course.tut_group_courses.assigned.count > 0
              session = ast.as_assessment.sessions.include_std(curr_user_course)
              if session.count > 0
                seat = Assessment::RealtimeSeatAllocation.where(std_course_id: curr_user_course.id, session_id: session.last.id).last
                t_attempting = ast.training ? (sub_ids.include? ast.training.assessment.id and !sub_map[ast.training.assessment.id].attempting? ? true : false) : nil
                m_attempting = ast.mission ? (sub_ids.include? ast.mission.assessment.id and !sub_map[ast.mission.assessment.id].attempting? ? true : false) : nil

                action_map[ast.id] = {action: "realtime_session", warning: nil,
                                      training: t_attempting.nil? ? {action: "Null",flash: "No Training"} :
                                          ( t_attempting ? {action: "Review",flash: "Review Training",url: course_assessment_submission_path(@course, ast.training.assessment,sub_map[ast.training.assessment.id])} :
                                              (session.started.count == 0 ? {action: "Notstart",flash: "Attempt Training"} : ((sub_ids.include? ast.training.assessment.id) ? {action: "Resumetraining",flash: "Resume Training",url: edit_course_assessment_submission_path(@course, ast.training.assessment,sub_map[ast.training.assessment.id])} :
                                                  {action: "Attempttraining",flash: "Attempt Training",url: new_course_assessment_submission_path(@course, ast.training.assessment)}))),
                                      mission: m_attempting.nil? ? {action: "Null",flash: "No Mission"} :
                                          ( m_attempting ? {action: "Review",flash: "Review Mission",url: course_assessment_submission_path(@course, ast.mission.assessment,sub_map[ast.mission.assessment.id])} :
                                              ((sub_ids.include? ast.mission.assessment.id) ? {action: "Resumemission",flash: "Resume Mission",url: edit_course_assessment_submission_path(@course, ast.mission.assessment,sub_map[ast.mission.assessment.id])} :
                                                  {action: "Attemptmission",flash: "Attempt Mission",url: new_course_assessment_submission_path(@course, ast.mission.assessment)})),
                                      seat: (session.last.start_time and session.last.start_time < Time.now) ? (seat ? "Table #{seat.table_number} - Seat #{seat.seat_number}": "Not allocated") : "Not published"}
              elsif curr_user_course.tut_group_courses.has_group.count > 0
                t_attempting = ast.training ? (sub_ids.include? ast.training.assessment.id and !sub_map[ast.training.assessment.id].attempting? ? true : false) : nil
                m_attempting = ast.mission ? (sub_ids.include? ast.mission.assessment.id and !sub_map[ast.mission.assessment.id].attempting? ? true : false) : nil

                action_map[ast.id] = {action: "realtime_session", warning: "Absent", seat: "Not allocated"}
                action_map[ast.id][:training] = {action: "Review",flash: "Review Training",url: course_assessment_submission_path(@course, ast.training.assessment,sub_map[ast.training.assessment.id])} if t_attempting
                action_map[ast.id][:mission] = {action: "Review",flash: "Review Mission",url: course_assessment_submission_path(@course, ast.mission.assessment,sub_map[ast.mission.assessment.id])} if m_attempting
              else
                action_map[ast.id] = {action: "realtime_session", warning: "No session", seat: "Not allocated"}
              end
            else
              action_map[ast.id] = {action: "realtime_session", warning: "No group", seat: "Not allocated"}
            end

          else
            action_map[ast.id] = {action: "Attempt",
                                  url: new_course_assessment_submission_path(@course, ast)}
          end

        if ast.is_policy_mission?
          @listed_tags[ast.id] = nil
        end 
      else
        action_map[ast.id] = {action: nil}
      end

      if ast.is_policy_mission? and ast.specific.revealAnswers? (curr_user_course)
        action_map[ast.id][:actionTertiary] = "Answers"
        action_map[ast.id][:urlTertiary] = answer_sheet_course_assessment_policy_mission_path(@course, ast.specific)
      end

      action_map[ast.id][:new] = false
      action_map[ast.id][:opened] = ast.opened?
      action_map[ast.id][:published] = ast.published
      action_map[ast.id][:title_link] =
          can?(:manage, ast) ?
              stats_course_assessment_path(@course, ast) :
              ast.get_path
    end

    @summary = {selected_tags: selected_tags || [],
                actions: action_map,
                columns: display_columns,
                time_format: time_format,
                paging: paging,
                module: assessment_type.humanize
    }

    if curr_user_course.id
      unseen = @assessments - curr_user_course.seen_assessments
      unseen.each do |um|
        action_map[um.id][:new] = true
        curr_user_course.mark_as_seen(um)
      end
    end
  end


  def show
    @summary = {}
    @summary[:questions] = @assessment.questions
  end

  def stats
    @summary = {}
		if @assessment.is_mission?
			redirect_to course_stats_mission_path(@course, @assessment.specific)
		elsif @assessment.is_training?
			redirect_to course_stats_training_path(@course, @assessment.specific)
		elsif @assessment.is_policy_mission?
			redirect_to course_stats_policy_mission_path(@course, @assessment.specific)
		end
  end

  def reorder
    @assessment.question_assessments.reordering(params['sortable-item'])
    #TODO; we need to clean up dependency after reordering

    render nothing: true
  end

  def overview
    authorize! :bulk_update, Assessment
    @display_columns = {}
    @course.assessment_columns(extract_type, true).each do |cp|
      @display_columns[cp.preferable_item.name] = cp.prefer_value
    end
  end

  def bulk_update
    authorize! :bulk_update, Assessment
    if @course.update_attributes(params[:course])
      flash[:notice] = "Assessment(s) updated successfully."
    else
      flash[:error] = "Assessment(s) failed to update. You may have put an open time that is after #{extract_type == 'missions' ? 'end time' : 'bonus cutoff time'}"
    end
  end

  def listall
    assessment_type = params[:type]

    @summary = {type: assessment_type}
    @summary[:selected_asm] = @course.assessments.find(params[:asm]) if params[:asm] && params[:asm] != "0"
    @summary[:selected_std] = @course.user_courses.find(params[:student]) if params[:student] && params[:student] != "0"
    @summary[:selected_staff] = @course.user_courses.find(params[:tutor]) if params[:tutor] && params[:tutor] != "0"


    assessments = @course.assessments.send(assessment_type)
    @summary[:stds] = @course.student_courses.order(:name)
    @summary[:staff] = @course.user_courses.staff

    sbms = @summary[:selected_asm] ? @summary[:selected_asm].submissions : assessments.submissions
    sbms = sbms.accessible_by(current_ability).where('status != ?','attempting').order(:submitted_at).reverse_order

    if @summary[:selected_std]
      sbms = sbms.where(std_course_id: @summary[:selected_std])
    elsif @summary[:selected_staff]
      sbms = sbms.where(std_course_id: @summary[:selected_staff].get_my_stds)
    end

    if curr_user_course.is_student?
      sbms = sbms.joins(:assessment).where("assessments.published =  1")
    end

    #@unseen = []
    #if curr_user_course.id
    #  @unseen = sbms - curr_user_course.get_seen_sbms
    #  @unseen.each do |sbm|
    #    curr_user_course.mark_as_seen(sbm)
    #  end
    #end

    sbms_paging = nil
    if assessment_type == "training"
      sbms_paging = @course.paging_pref('TrainingSubmissions')
    else
      sbms_paging= @course.paging_pref('MissionSubmissions')
    end

    if sbms_paging.display?
      sbms = sbms.page(params[:page]).per(sbms_paging.prefer_value.to_i)
    end

    @summary[:asms] = assessments
    @summary[:sbms] = sbms
    @summary[:paging] = sbms_paging
  end

  def download_file
    #redirect_to material.file.file_url
    file = FileUpload.find_by_id(params[:file_id].to_i)

    #send_file "#{Rails.root}/#{file.file_url}",
    send_file "#{Rails.root}/public/Assessment/#{params[:id]}/files/#{file.original_name}",
              :filename => params[:filename],
              :type => file.file_content_type
  end

  def access_denied
  end

  private

  def extract_type
    controller = request.filtered_parameters["controller"].split('/').last
    controller.singularize
  end
end
