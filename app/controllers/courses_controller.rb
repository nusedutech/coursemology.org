class CoursesController < ApplicationController
  load_and_authorize_resource
  before_filter :load_general_course_data, only: [:show, :students, :pending_gradings, :manage_students, :check_before_import, :import_ivle_student]

  def index
    @courses = Course.online_course
  end

  def create
    @course = Course.new(params[:course])
    @course.creator = current_user
    @course.levels.build({ level: 0, exp_threshold: 0  })

    user_course = @course.user_courses.build()
    user_course.course = @course
    user_course.user = current_user
    user_course.role = Role.find_by_name(:lecturer)    
    
    respond_to do |format|
      if @course.save  && user_course.save
        
        tag_group = TagGroup.new
        tag_group.course_id = @course.id
        tag_group.name = 'Difficulty'
        tag_group.save
        
        ['Easy','Medium','Hard','Unspecified'].each do |t|
          tag = Tag.new
          tag.name = t
          tag.course_id = @course.id
          tag.tag_group_id = tag_group.id
          tag.save
        end

        invisible_default_forum = ForumForum.create(:name => "Entry Forum", :description => "Store discussions of Lesson Plan")
        invisible_default_forum.course = @course
        invisible_default_forum.save
        
        
        format.html { redirect_to course_preferences_path(@course),
                                  notice: "The course '#{@course.title}' has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  respond_to :html, :json

  def update
    message = nil
    if params[:user_course_id]
      uc = @course.user_courses.where(id:params[:user_course_id]).first
      uc.role_id = params[:role_id]
      uc.save
    end
    if params[:course_atts]
      params[:course_atts].each do |id, val|
        ca = CourseThemeAttribute.find(id)
        ca.value = val
        ca.save
      end
    end
    if params[:course]
      if params[:course][:is_publish] || params[:course][:is_open]
        is_publish = params[:course][:is_publish].to_i == 1 ? true : false
        is_open = params[:course][:is_open].to_i == 1 ? true : false
        if is_publish != @course.is_publish? || is_open != @course.is_open?
          authorize! :manage, :course_admin
        end
      end
    end

    if params[:course_owner]
      user = User.where(id: params[:course_owner]).first
      @course.creator = user
      @course.is_publish = params[:is_publish] == 'true'
      @course.save
    end
    respond_to do |format|
      if params[:user_course_id]
        format.html { redirect_to course_staff_url(@course),
                                  notice: 'New staff added.'}
      elsif params[:course_owner]
        format.json {render json:  {course:@course, owner: @course.creator.name } }
      elsif @course.update_attributes(params[:course])
        format.html { redirect_to course_preferences_path(@course),
                                  notice: 'Course setting has been updated.' }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def new
    respond_to do |format|
      format.html
    end
  end

  def show
    if can?(:participate, Course) || can?(:share, Course)

      unless curr_user_course.new_record?
        curr_user_course.update_attribute(:last_active_time, Time.now)
      end
      @announcement_pref = @course.home_announcement_pref
      if @announcement_pref.display?
        no_to_display = @course.home_announcement_no_pref.prefer_value.to_i
        @announcements = @course.announcements.accessible_by(current_ability).
            where("expiry_at > ?", Time.now).
            order("publish_at DESC").first(no_to_display)
        @is_new = {}
        if curr_user_course.id
          unseen = @announcements - curr_user_course.seen_announcements
          unseen.each do |ann|
            @is_new[ann.id] = true
            curr_user_course.mark_as_seen(ann)
          end
        end
      end

      @activities_pref = @course.home_activities_pref
      if @activities_pref.display?
        @activities = @course.activities.order("created_at DESC").first(@course.home_activities_no_pref.prefer_value.to_i)
      end

      #TODO
      @pending_actions = curr_user_course.pending_actions.includes(:item).to_show.
          select { |pa| pa.item.published? && pa.item.open_at < Time.now }.
          sort_by {|pa| pa.item.close_at || Time.now }.first(3)

      respond_to do |format|
        format.html
      end
    else
      respond_to do |format|
        format.html { render "courses/about" }
      end
    end
  end

  def destroy
    authorize! :destroy, @course
    title = @course.title
    @course.is_pending_deletion = true
    @course.save
    #@course.destroy
    @course.lect_courses.each do |uc|
      UserMailer.delay.course_deleted(@course.title, uc.user)
    end
    Delayed::Job.enqueue(BackgroundJob.new(@course.id, :delete_course))
    respond_to do |format|
      flash[:notice] = "The course '#{title}' is pending for deletion."
      redirect_url = params[:origin] || courses_url
      format.html { redirect_to redirect_url }
      format.json { head :no_content }
    end
  end

  def students
    @lecturer_courses = @course.user_courses.lecturer
    @student_courses = @course.user_courses.student.where(is_phantom: false)
    @ta_courses = @course.user_courses.tutor

    @std_paging = @course.paging_pref('students')
    if @std_paging.display?
      @student_courses = Kaminari.paginate_array(@student_courses).page(params[:page]).per(@std_paging.prefer_value.to_i)
    end

  end

  def check_before_import
    @check_list = TutorialGroup.check(params[:file], @course)
  end

  def import_student_groups
    TutorialGroup.import(params[:students], current_user, @course)
    respond_to do |format|
      format.html { redirect_to course_manage_students_path(@course),
                                notice: "import successfully" }
    end
  end

  def manage_students
    authorize! :manage, UserCourse
    if params[:phantom] && params[:phantom] == 'true'
      @phantom = true
    else
      @phantom = false
    end

    @student_courses = @course.user_courses.student.where(is_phantom: @phantom).order('lower(name)')
    if sort_column == 'tutor'
      @student_courses = @student_courses.sort_by {|uc| uc.tut_courses.first ? uc.tut_courses.first.id : 0  }
      if sort_direction == 'asc'
        @student_courses = @student_courses.reverse
      end
    end

    @staff_courses = @course.user_courses.staff
    @student_count = @student_courses.length

    @std_paging = @course.paging_pref('ManageStudents')
    if @std_paging.display?
      @student_courses = Kaminari.paginate_array(@student_courses).page(params[:page]).per(@std_paging.prefer_value.to_i)
    end

  end

  def pending_gradings
    authorize! :see, :pending_gradings
    @pending_gradings = @course.pending_gradings(curr_user_course)
  end

  def import_ivle_student
    count = 0
    if params["import_ivle_student"] && params["import_ivle_student"]["chose"]
      params["import_ivle_student"]["chose"].each do |e|
          email = params["import_ivle_student"]["email"][e]=="" ? (e + "@nus.edu.sg") : params["import_ivle_student"]["email"][e]
          name = params["import_ivle_student"]["name"][e]
          password = User.new(password: e).encrypted_password
          @user = User.new(:name => name, :email => email, :student_id => e, :password => password, :password_confirmation => password, :system_role_id => 2)
          @user.skip_confirmation!
          @user.save

          @course.enrol_user(@user, Role.find_by_name("student"))
          count = count+1
      end
      respond_to do |format|
        if count > 0
          format.html { redirect_to course_manage_students_path(@course), notice: "Imported #{count} students." }
        else
          format.html { redirect_to course_manage_students_path(@course)}
        end
      end
    end
  end

  def download_import_template
    @students = @course.user_courses.student.where(is_phantom: false).order('lower(name) asc')
    file = Tempfile.new('import-student-group-template')
    file.puts "id,name,email,group,remark\n"

    @students.each do |student|
      file.puts student.user.student_id + "," +
                    student.name.gsub(",", " ") + "," +
                    student.user.email + "," +
                    (TutorialGroup.where(:std_course_id => student.id).first ? TutorialGroup.where(:std_course_id => student.id).first.group.name : "") + "," +
                    "" + "\n"
    end

    file.close
    send_file(file.path, {
        :type => "application/csv",
        :disposition => "attachment",
        :filename =>   @course.title + " - Import Question Template.csv"
    })

    #send_file "#{Rails.root}/public/import-student-group-template.csv",
    #          :filename => "import-student-group-template.csv",
    #          :type => "application/csv"
  end


end
