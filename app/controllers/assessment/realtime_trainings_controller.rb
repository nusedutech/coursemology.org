class Assessment::RealtimeTrainingsController < Assessment::AssessmentsController
  load_and_authorize_resource :realtime_training, class: "Assessment::RealtimeTraining", through: :course

  def show
    if curr_user_course.is_student? && !current_user.is_admin?
      redirect_to course_assessment_realtime_trainings_path
      return
    end
    @assessment = @realtime_training.assessment
    super

    @summary[:allowed_questions] = [Assessment::McqQuestion, Assessment::CodingQuestion]
    @summary[:type] = 'realtime_training'
    @summary[:specific] = @realtime_training

    #reset all session
    @realtime_training.sessions.each do |s|
      s.update_attribute(:status, false)
    end

    respond_to do |format|
      format.html { render "assessment/assessments/show" }
    end
  end

  def new
    tab_id = params[:tab]
    if Tab.find_by_id(tab_id)
      @realtime_training.tab_id = tab_id
    end
    @realtime_training.exp = 200
    @realtime_training.open_at = DateTime.now.beginning_of_day
    @realtime_training.bonus_exp = 0
    @realtime_training.bonus_cutoff_at = DateTime.now.beginning_of_day + 1
    @tags = @course.tags
    @course.student_groups.each do |g|
      @realtime_training.sessions.new(student_group_id: g.id, number_of_table: 1, seat_per_table: 1)
    end

    @asm_tags = {}
  end

  def create
    @realtime_training.position = @course.trainings.count + 1
    @realtime_training.creator = current_user
    @realtime_training.course_id = @course.id
    if params[:files]
      @realtime_training.attach_files(params[:files].values)
    end

    respond_to do |format|
      if @realtime_training.save
        @realtime_training.sessions.each do |s|
          s.allocate_seats
        end
        @realtime_training.create_local_file
        format.html { redirect_to course_assessment_realtime_training_path(@course, @realtime_training),
                                  notice: "The Realtime Training '#{@realtime_training.title}' has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def edit
    @tags = @course.tags
    if @realtime_training.sessions.empty?
      @course.student_groups.each do |g|
        @realtime_training.sessions.new(student_group_id: g.id, number_of_table: 1, seat_per_table: 1)
      end
    end
  end

  def update
    respond_to do |format|
      if @realtime_training.update_attributes(params[:assessment_realtime_training])
        format.html { redirect_to course_assessment_realtime_training_url(@course, @realtime_training),
                                  notice: "realtime training #{@realtime_training.title} has been updated." }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def update_questions
    if !params[:assessment].nil?
      ques_list = params[:assessment][:question_assessments]
    end

    if (!ques_list.nil?)
      old_list = @realtime_training.question_assessments
      ques_list.each do |q|
        if old_list.where(:question_id => q).count === 0
          qa = QuestionAssessment.new
          qa.question_id = q
          qa.assessment_id =  @realtime_training.assessment.id
          qa.position = @realtime_training.questions.count
          qa.save

          #create session_question
          @realtime_training.sessions.each do |s|
            s.session_questions.create(question_assessment_id: qa.id, unlock: false, unlock_count: 0)
          end
        end
      end
      old_list.each do |qa|
        if !ques_list.include? qa.question.id.to_s
          qa.destroy
        end
      end
    end

    respond_to do |format|
      if @realtime_training.update_attributes(params[:assessment_realtime_training])
        format.html { redirect_to course_assessment_realtime_training_url(@course, @realtime_training),
                                  notice: "The realtime training '#{@realtime_training.title}' has been updated." }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def update_seating_plan
    respond_to do |format|
      params[:data].values.each do |d|
        seat = Assessment::RealtimeTrainingSession.find(d[:session]).get_student_seats_by_seat(d[:table],d[:seat]).first
        if !seat.nil?
          seat.update_attribute(:std_course_id, d[:student])
        else
          Assessment::RealtimeTrainingSession.find(d[:session]).student_seats.create(table_number: d[:table], seat_number: d[:seat], std_course_id: d[:student])
        end
      end
      format.json { render json: { result: true}}
    end
  end

  def destroy
    @realtime_training.destroy

    respond_to do |format|
      format.html { redirect_to course_assessment_realtime_trainings_url,
                                notice: "The realtime training '#{@realtime_training.title}' has been removed." }
    end
  end



  def stats
    @submissions = @realtime_training.training_submissions
    @std_courses = @course.user_courses.student.order(:name).where(is_phantom: false).order('lower(name)')
    @my_std_courses = curr_user_course.std_courses.order(:name)
  end

  def overview
    super
    @tabs = @course.training_tabs
    @tab_id = 'overview'
  end


end

