class Assessment::RealtimeSessionGroupsController < Assessment::AssessmentsController
  load_and_authorize_resource :realtime_session_group, class: "Assessment::RealtimeSessionGroup", through: :course

  def show
    if curr_user_course.is_student? && !current_user.is_admin?
      redirect_to course_assessment_realtime_trainings_path
      return
    end
    @assessment = @realtime_session_group.assessment
    super

    @summary[:allowed_questions] = []
    @summary[:type] = 'realtime_session_group'
    @summary[:specific] = @realtime_session_group

    #reset all session
    @realtime_session_group.sessions.each do |s|
      s.update_attribute(:status, false)
    end

    respond_to do |format|
      format.html { render "assessment/assessments/show" }
    end
  end

  def new
    tab_id = params[:tab]
    if Tab.find_by_id(tab_id)
      @realtime_session_group.tab_id = tab_id
    end
    @realtime_session_group.open_at = DateTime.now.beginning_of_day
    @tags = @course.tags
    @course.student_groups.each do |g|
      @realtime_session_group.sessions.new(student_group_id: g.id, number_of_table: 1, seat_per_table: 1)
    end

    @asm_tags = {}
  end

  def create
    @realtime_session_group.position = @course.trainings.count + 1
    @realtime_session_group.creator = current_user
    @realtime_session_group.course_id = @course.id
    if params[:files]
      @realtime_session_group.attach_files(params[:files].values)
    end

    respond_to do |format|
      if @realtime_session_group.save
        @realtime_session_group.sessions.each do |s|
          s.allocate_seats
        end
        @realtime_session_group.update_session_questions(nil, nil)
        @realtime_session_group.create_local_file
        format.html { redirect_to course_assessment_realtime_session_group_path(@course, @realtime_session_group),
                                  notice: "The Realtime Session Group '#{@realtime_session_group.title}' has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def edit
    @tags = @course.tags
    if @realtime_session_group.sessions.empty?
      @course.student_groups.each do |g|
        @realtime_session_group.sessions.new(student_group_id: g.id, number_of_table: 1, seat_per_table: 1)
      end
    end
  end

  def update
    respond_to do |format|
      old_training = @realtime_session_group.training
      old_mission = @realtime_session_group.mission
      if @realtime_session_group.update_attributes(params[:assessment_realtime_session_group])
        @realtime_session_group.update_session_questions(old_training,old_mission)
        format.html { redirect_to course_assessment_realtime_session_group_url(@course, @realtime_session_group),
                                  notice: "Realtime Session Group #{@realtime_session_group.title} has been updated." }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def update_seating_plan
    respond_to do |format|
      params[:data].values.each do |d|
        seat = Assessment::RealtimeSession.find(d[:session]).get_student_seats_by_seat(d[:table],d[:seat]).first
        if !seat.nil?
          seat.update_attribute(:std_course_id, d[:student])
        else
          Assessment::RealtimeSession.find(d[:session]).student_seats.create(table_number: d[:table], seat_number: d[:seat], std_course_id: d[:student])
        end
      end
      format.json { render json: { result: true}}
    end
  end

  def destroy
    @realtime_session_group.destroy

    respond_to do |format|
      format.html { redirect_to course_assessment_realtime_session_groups_url,
                                notice: "Realtime Session Group '#{@realtime_session_group.title}' has been removed." }
    end
  end
end
