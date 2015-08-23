class CourseGroupsController < ApplicationController
  load_and_authorize_resource :course
  before_filter :load_general_course_data, only: [:manage_group,:add_student]
  before_filter :access_control

  def manage_group
    @students_courses = @course.user_courses.student.order('lower(name)')

    @assigned_students = @course.tutorial_groups.map {|m| m.std_course}
    @my_std_courses = curr_user_course.std_courses.order('lower(name)')

    sort_key = ''

    if sort_column == 'Name'
      sort_key = 'lower(name) '
    end

    if sort_column == 'Level'
      sort_key = 'level_id '
    end

    if sort_column == 'Exp'
      sort_key = 'exp '
    end

    if  sort_column
      @my_std_courses = curr_user_course.std_courses.order(sort_key + sort_direction)
    end
  end

  def add_student
    tg_exist = @course.tutorial_groups.find_by_tut_course_id_and_std_course_id(curr_user_course,params[:std_course_id])
    if params[:_innerdelstudentform]
      remove_student(tg_exist)
      return
    end

    unless tg_exist
      tg = @course.tutorial_groups.build
      tg.std_course_id = params[:std_course_id]
      tg.tut_course = curr_user_course
      tg.save
    end

    respond_to do |format|
      if tg_exist
        format.html { redirect_to course_manage_group_url(@course),
                                  notice: "Student already in your group."}
      else
        format.html { redirect_to course_manage_group_url(@course) }
      end
    end
  end

  def remove_student(tutorial_group)
    respond_to do |format|
      if tutorial_group
        tutorial_group.destroy
        format.html { redirect_to course_manage_group_url(@course),
                                  notice:"Student has been successfully removed." }
      else
        format.html { redirect_to course_manage_group_url(@course),
                                  alert:"This student is not in your group!" }
      end
    end
  end

  def update_exp
    authorize! :award_points, UserCourse
    exps = params[:EXP]
    if exps
      count = 0
      exps.each do |std_course_id, exp_str|
        exp = exp_str.to_i
        if exp != 0
          curr_user_course.manual_exp_award(std_course_id,exp,params[:reason])
          count += 1
        end
      end
    end
    respond_to do |format|
      format.html { redirect_to course_manage_group_url,
                                notice: "EXPs have been awarded to #{count} students!"}
    end
  end

  def update_group
    group = StudentGroup.find(params["group_id"]) if params["group_id"]
    if group
      group.update_attribute(:name, params[:change_name]) if params[:change_name] and params[:change_name] != group.name
      tutor_id = (!params[:tutor] or params[:tutor] == '-1') ? nil : params[:tutor].to_i
      if group.tutor_id != tutor_id
        group.tutor_id = tutor_id
        group.save
        group.tutorial_groups.each do |t|
          t.tut_course_id = tutor_id
          t.save
        end
      end
    end
    respond_to do |format|
      format.json { render json: { status: 'OK' } }
    end
  end

  def remove_group
    #@user_course.role = Role.student.first
    #@user_course.save
    respond_to do |format|
      format.json { render json: { status: 'OK' } }
      format.html { redirect_to course_students_path(@course) }
    end
  end

  private
  def access_control
    unless curr_user_course.is_staff?
      redirect_to access_denied_url, alert: 'Sorry dude! You are not authorized to access this page.'
    end
  end
end
