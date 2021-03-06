class Assessment::TrainingsController < Assessment::AssessmentsController
  load_and_authorize_resource :training, class: "Assessment::Training", through: :course


  def show
    if curr_user_course.is_student? && !current_user.is_admin?
      redirect_to course_assessment_trainings_path
      return
    end
    @assessment = @training.assessment
    super

    @summary[:allowed_questions] = [Assessment::McqQuestion, Assessment::CodingQuestion]
    @summary[:type] = 'training'
    @summary[:specific] = @training

    respond_to do |format|
      format.html { render "assessment/assessments/show" }
    end
  end

  def new
    tab_id = params[:tab]
    if Tab.find_by_id(tab_id)
      @training.tab_id = tab_id
    end
    @test_flag = params[:test] == "true" ? true : false
    @training.exp = 200
    @training.open_at = DateTime.now.beginning_of_day
    @training.bonus_exp = 0
    @training.bonus_cutoff_at = DateTime.now.beginning_of_day + 1
    @training.duration = 0 if @test_flag
    @tags = @course.tags
    @asm_tags = {}
  end

  def create
    @training.position = @course.trainings.count + 1
    @training.creator = current_user
    @training.course_id = @course.id
    @training.test = @training.duration ? true : false
    @training.duration = @training.duration.nil? ? 0 : @training.duration
    if params[:files]
      @training.attach_files(params[:files].values)
    end

    respond_to do |format|
      if @training.save
        @training.create_local_file
        format.html { redirect_to course_assessment_training_path(@course, @training),
                                  notice: "The #{@training.test ? 'test' : 'training'} '#{@training.title}' has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def edit
    @tags = @course.tags
  end

  def update
    respond_to do |format|
      if @training.update_attributes(params[:assessment_training])
        format.html { redirect_to course_assessment_training_url(@course, @training),
                                  notice: "The #{@training.test ? 'test' : 'training'} '#{@training.title}' has been updated." }
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
      old_list = @training.question_assessments
      ques_list.each do |q|
        if old_list.where(:question_id => q).count === 0
          qa = QuestionAssessment.new
          qa.question_id = q
          qa.assessment_id =  @training.assessment.id
          qa.position = @training.questions.count
          qa.save
        end
      end
      old_list.each do |qa|
        if !ques_list.include? qa.question.id.to_s
          qa.destroy
        end
      end
    end

    @training.update_max_grade
    respond_to do |format|
      if @training.save and @training.update_attributes(params[:assessment_training])

        format.html { redirect_to course_assessment_training_url(@course, @training),
                                  notice: "The training '#{@training.title}' has been updated." }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @training.destroy

    respond_to do |format|
      format.html { redirect_to course_assessment_trainings_url,
                                notice: "The training '#{@training.title}' has been removed." }
    end
  end

  def stats
    @submissions = @training.training_submissions
    @std_courses = @course.user_courses.student.order(:name).where(is_phantom: false).order('lower(name)')
    @my_std_courses = curr_user_course.std_courses.order(:name)
  end

  def overview
    super
    @tabs = @course.training_tabs
    @tab_id = 'overview'
  end

  def bulk_update
    super
    redirect_to overview_course_assessment_trainings_path
  end

  def duplicate_qn
    asm_qn = AsmQn.where(qn_type:params[:qtype], qn_id: params[:qid]).first
    to_asm = Training.find(params[:to])
    is_move = params[:move] == 'true'

    clone = Duplication.duplicate_qn_no_log(asm_qn.qn)
    new_link = asm_qn.dup
    new_link.qn = clone
    new_link.asm = to_asm
    new_link.pos = to_asm.asm_qns.count

    clone.save
    new_link.save
    to_asm.update_max_grade

    if is_move
      asm = asm_qn.asm
      asm_qn.destroy
      asm.update_max_grade
      asm.update_qns_pos
    end

    render nothing: true
  end
end
