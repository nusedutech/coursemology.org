class Assessment::Grading < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :grader, class_name: User
  belongs_to :grader_course, class_name: UserCourse
  belongs_to :student, class_name: UserCourse, foreign_key: :std_course_id
  belongs_to :exp_transaction
  belongs_to :submission, class_name: Assessment::Submission

  has_many  :answer_gradings, class_name: Assessment::AnswerGrading
  has_many  :grading_logs, class_name: Assessment::GradingLog, dependent: :destroy

  after_save  :update_exp_transaction, if: :grade_or_exp_changed?
  after_save  :create_log, if: :grade_or_exp_changed?
  after_create  :send_notification


  def grade_or_exp_changed?
    asm = submission.assessment
    if submission.done? and asm.is_training? and asm.as_assessment.always_full_exp
      true
    else
      exp_changed? or grade_changed?
    end

  end

  def create_log
    grading_logs.create({grade: grade,
                         exp: exp,
                         grader_course_id: grader_course_id,
                         grader_id: grader_id},
                        :without_protection => true)
  end

  def update_grade
    self.grade = answer_gradings.sum(&:grade)
  end

  def update_exp_transaction

    asm = submission.assessment
    if !asm.is_training? or (asm.is_training? and asm.as_assessment.realtime_session_groups.select { |g| !g.recitation? }.count == 0)
      if !student and submission.std_seats.count>0
        submission.std_seats.each do |s|
          exp_tran = ExpTransaction.where(user_course_id: s.std_course_id,rewardable_id: submission.id,rewardable_type: submission.class.name).first
          unless exp_tran
            exp_tran = ExpTransaction.create({giver_id: self.grader_id,
                                                        user_course_id: s.std_course_id,
                                                        reason: "Exp for #{asm.title}",
                                                        is_valid: true,
                                                        rewardable_id: submission.id,
                                                        rewardable_type: submission.class.name },
                                                        without_protection: true)
          end
          exp_tran.exp = self.exp || (asm.max_grade.nil? ? 0 : (self.grade || 0) * asm.exp / asm.max_grade)
          if submission.has_multiplier?
            exp_tran.exp *= submission.multiplier
          else
            exp_tran.exp += submission.get_bonus if submission.done?
          end

          exp_tran.save
        end
      else
        unless self.exp_transaction
          self.exp_transaction = ExpTransaction.create({giver_id: self.grader_id,
                                                        user_course_id: submission.std_course_id,
                                                        reason: "Exp for #{asm.title}",
                                                        is_valid: true,
                                                        rewardable_id: submission.id,
                                                        rewardable_type: submission.class.name },
                                                       without_protection: true)
          self.save
        end
        if (submission.done? and asm.is_training? and asm.as_assessment.always_full_exp) or (asm.is_policy_mission? and submission.submitted?)
          self.exp_transaction.exp = asm.exp
        else
          self.exp_transaction.exp = self.exp || (asm.max_grade.nil? ? 0 : (self.grade || 0) * asm.exp / asm.max_grade)
        end

        if submission.has_multiplier?
          self.exp_transaction.exp *= submission.multiplier
        else
          self.exp_transaction.exp += submission.get_bonus if submission.done?
        end

        self.exp_transaction.save
      end


    end
  end

  def send_notification
    if student
      course = student.course
      asm = submission.assessment
      if asm.is_mission? and asm.published? and student.is_student? and course.email_notify_enabled?(PreferableItem.new_grading)
        UserMailer.delay.new_grading(
            student,
            self)
      end
    end
  end
end
