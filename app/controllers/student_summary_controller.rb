class StudentSummaryController < ApplicationController
  load_and_authorize_resource :course
  before_filter :load_general_course_data

  def index
    authorize! :manage, UserCourse
    case sort_column
      when 'Exp'
        @students = @course.user_courses.student.where(is_phantom: false).order("exp " + sort_direction)
      when 'Level'
        @students = @course.user_courses.student.where(is_phantom: false).order("level_id " + sort_direction)
      when 'Name'
        @students = @course.user_courses.student.where(is_phantom: false)
        @students = sort_direction == 'asc' ? @students.order('lower(name)') : @students.order('lower(name) desc')
      else
        @students = @course.user_courses.student.where(is_phantom: false).order("exp desc")
    end


    @students = @students.includes(:exp_transactions)
    @std_summary_paging = @course.paging_pref('StudentSummary')
    if @std_summary_paging.display?
      @students = @students.page(params[:page]).per(@std_summary_paging.prefer_value.to_i)
    end

    @phantom_students = @course.user_courses.student.where(is_phantom: true).order("exp desc")
  end

  def export
    @students = @course.user_courses.student.where(is_phantom: false).order('lower(name) asc')
    file = Tempfile.new('student_summary')
    file.puts "Student, Tutor, Level, EXP, EXP Count \n"

    @students.each do |student|
     file.puts student.name.gsub(",", " ") + "," +
                   student.get_my_tutor_name.gsub(",", " ") + "," +
                   student.level.level.to_s + "," +
                   student.exp.to_s + "," +
                   student.exp_transactions.length.to_s + "\n"
    end

    file.close
    send_file(file.path, {
        :type => "application/zip, application/octet-stream",
        :disposition => "attachment",
        :filename =>   @course.title + " - Student Summary.csv"
    }
              )
  end

  def export_result
    @students = @course.user_courses.student.where(is_phantom: false).order('lower(name) asc')
    file = Tempfile.new('student_result')

    file.puts "id, name, email, group, #{@course.assessments.map {|a| "#{a.title}_easy,#{a.title}_medium,#{a.title}_hard" }.join(',')} \n"

    @students.each do |student|
       input = student.user.name.gsub(",", " ") + "," +
                    student.user.name.gsub(",", " ") + "," +
                    student.user.email + "," +
                    (TutorialGroup.where(:std_course_id => student.id).first ? TutorialGroup.where(:std_course_id => student.id).first.group.name : "")
       @course.assessments.each do |a|
         std_sub = Assessment::Submission.where(:assessment_id => a.id, :std_course_id => student.id).first
         easy = medium = hard = ""
         if std_sub
           std_sub.answers.each do |an|
             if an.question.tags.include? @course.tag_groups.where(:name => 'Difficulty').first.tags.where(:name => 'Easy').first
               if an.correct
                 easy += "1"
               else
                 easy += "0"
               end
             elsif an.question.tags.include? @course.tag_groups.where(:name => 'Difficulty').first.tags.where(:name => 'Medium').first
               if an.correct
                 medium += "1"
               else
                 medium += "0"
               end
             elsif an.question.tags.include? @course.tag_groups.where(:name => 'Difficulty').first.tags.where(:name => 'Hard').first
               if an.correct
                 hard += "1"
               else
                 hard += "0"
               end
             end
           end
         end
         input += ',="' + easy + '",="' + medium+ '",="' + hard + '"'
       end
       file.puts input
    end

    file.close
    send_file(file.path, {
        :type => "application/zip, application/octet-stream",
        :disposition => "attachment",
        :filename =>   @course.title + " - Student Summary.csv"
    }
    )
  end
end
