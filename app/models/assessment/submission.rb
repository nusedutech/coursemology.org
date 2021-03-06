class Assessment::Submission < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :created_at, :updated_at, :std_course_id

  include Rails.application.routes.url_helpers

  scope :mission_submissions, -> {
    joins("left join assessments on assessment_submissions.assessment_id = assessments.id ").
        where("assessments.as_assessment_type = 'Assessment::Mission'") } do
    def without_rt_individual(course)
      where("assessment_submissions.std_course_id is null or assessments.as_assessment_type <> 'Assessment::Mission' or
            (assessments.as_assessment_type = 'Assessment::Mission' and assessment_submissions.std_course_id is not null and assessments.as_assessment_id not in (?))",
             course.realtime_session_groups.where("mission_id is not null").select(:mission_id).uniq.map(&:mission_id).push(0))
    end
    def std_without_rt_individual(course,std)
      where("(assessment_submissions.std_course_id is null and assessment_submissions.id in (?)) or
            (assessments.as_assessment_type <> 'Assessment::Mission' and assessment_submissions.std_course_id = (?)) or
            (assessments.as_assessment_type = 'Assessment::Mission' and assessment_submissions.std_course_id = (?) and assessments.as_assessment_id not in (?))",
          Assessment::RealtimeSeatAllocation.where(std_course_id: std.id).select(:team_submission_id).uniq.map(&:team_submission_id).push(0),
          std.id,std.id, course.realtime_session_groups.where("mission_id is not null").select(:mission_id).uniq.map(&:mission_id).push(0))
    end
  end

  scope :training_submissions, -> {
    joins("left join assessments on assessment_submissions.assessment_id = assessments.id ").
        where("assessments.as_assessment_type = 'Assessment::Training'") }
	
	scope :policy_mission_submissions, -> {
    joins("left join assessments on assessment_submissions.assessment_id = assessments.id ").
        where("assessments.as_assessment_type = 'Assessment::PolicyMission'") }

  scope :realtime_training_submissions, -> {
    joins("left join assessments on assessment_submissions.assessment_id = assessments.id ").
        where("assessments.as_assessment_type = 'Assessment::RealtimeTraining'") }

  scope :graded, -> { where(status: 'graded') }

  scope :submitted_format, -> { where(status: 'submitted') }
  scope :attempting_format, -> { where(status: 'attempting') }

  scope :belong_to_stds, lambda { |std_list| where("std_course_id in (?)",std_list) }
  scope :group_submissions_stds, lambda { |group_list|
    joins("inner join assessment_realtime_seat_allocations on assessment_submissions.id = assessment_realtime_seat_allocations.team_submission_id").
        joins("inner join assessment_realtime_sessions on assessment_realtime_seat_allocations.session_id = assessment_realtime_sessions.id").
          where("assessment_realtime_sessions.student_group_id in (?)",group_list) }

  scope :without_rt_individual, lambda { |course|
    joins("inner join assessments on assessment_submissions.assessment_id = assessments.id ").
        where("assessment_submissions.std_course_id is null or assessments.as_assessment_type <> 'Assessment::Mission' or
            (assessments.as_assessment_type = 'Assessment::Mission' and assessment_submissions.std_course_id is not null and assessments.as_assessment_id not in (?))",
              course.realtime_session_groups.where("mission_id is not null").select(:mission_id).uniq.map(&:mission_id).push(0))
    }

  scope :std_without_rt_individual, lambda { |course,std|
    joins("inner join assessments asm on assessment_submissions.assessment_id = asm.id ").
        where("(assessment_submissions.std_course_id is null and assessment_submissions.id in (?)) or
            (asm.as_assessment_type <> 'Assessment::Mission' and assessment_submissions.std_course_id = (?)) or
            (asm.as_assessment_type = 'Assessment::Mission' and assessment_submissions.std_course_id = (?) and asm.as_assessment_id not in (?))",
              Assessment::RealtimeSeatAllocation.where(std_course_id: std.id).select(:team_submission_id).uniq.map(&:team_submission_id).push(0),
              std.id,std.id, course.realtime_session_groups.where("mission_id is not null").select(:mission_id).uniq.map(&:mission_id).push(0))
  }

  belongs_to :assessment
  belongs_to :std_course, class_name: "UserCourse"
  has_many :answers, class_name: Assessment::Answer, dependent: :destroy

  has_many :general_answers, class_name: "Assessment::GeneralAnswer",
           through: :answers,
           source: :as_answer, source_type: "Assessment::GeneralAnswer"

  has_many :coding_answers, class_name: "Assessment::CodingAnswer",
           through: :answers,
           source: :as_answer, source_type: "Assessment::CodingAnswer"

  has_many :mcq_answers, class_name: "Assessment::McqAnswer",
           through: :answers,
           source: :as_answer, source_type: "Assessment::McqAnswer"


  has_many :files, as: :owner, class_name: "FileUpload", dependent: :destroy
  has_many :gradings, class_name: Assessment::Grading, dependent: :destroy
  has_one :comment_topic, as: :topic

  # Dependent destroy - result in frozen hash error as co-owned, by both submission and
  # forward_policy_level - result when assessment is destroyed and all relations is deleted
  # together
  # Update might be required on MTI Gem
	has_many :progression_groups, class_name: "Assessment::ProgressionGroup"

  has_many :concept_stages, class_name: "Assessment::GuidanceConceptStage", dependent: :destroy, foreign_key: "assessment_submission_id"

  has_many :std_seats, class_name: Assessment::RealtimeSeatAllocation, foreign_key: :team_submission_id
  has_many :group_stds, through: :std_seats, source: :student
  after_create :set_attempting
  after_save   :status_change_tasks, if: :status_changed?


  def graders
    self.gradings.map(&:grader).select{|g| g}.map(&:name)
  end

  def get_final_grading(build_params = {})
    self.gradings.last || gradings.build(build_params)
  end

  def get_all_answers
    self.answers
  end

  #TODO
  def clear_final_answer(qn)
    self.answers.final.each do |sbm_ans|
      if sbm_ans.qn == qn
        sbm_ans.final = false
        sbm_ans.save
        break
      end
    end
  end

  def has_multiplier?
    self.respond_to?(:multiplier) && self.multiplier
  end

  def get_bonus
    specific = assessment.specific
    if specific.respond_to? :bonus_cutoff_at
      if specific.bonus_cutoff_at && specific.bonus_cutoff_at > Time.now
        return specific.bonus_exp
      end
    end
    0
  end

  def set_attempting
    self.update_attribute(:status,'attempting')
  end

  #TODO
  def set_submitted
    self.update_attribute(:status,'submitted')
    self.update_attribute(:submitted_at, updated_at)
  end

  def set_generated
    self.update_attribute(:status,'generated')
    self.update_attribute(:submitted_at, updated_at)
  end

  def set_graded
    self.update_attribute(:status,'graded')
  end

  def attempting?
    self.status == 'attempting'
  end

  def submitted?
    self.status == 'submitted'
  end

  def graded?
    self.status == 'graded'
  end

  def set_updated_timing
    self.updated_at = Time.now
    self.save
  end

  def get_path
    course_assessment_submission_path(std_course.course, assessment, self)
  end

  def get_new_grading_path
    '#'
  end

  def done?
    if (self.assessment.as_assessment.is_a?(Assessment::Training) and (self.assessment.as_assessment.test or self.assessment.as_assessment.realtime_session_groups.count > 0)) or
        self.assessment.as_assessment.is_a?(Assessment::RealtimeTraining)
      self.assessment.questions.finalised_for_test(self).count == self.assessment.questions.count
    else
      self.assessment.questions.finalised(self).count == self.assessment.questions.count
    end
  end

  def update_grade(full_grade = false)
    self.submitted_at = DateTime.now
    self.set_graded

    pending_action = std_course.pending_actions.where(item_type: self.assessment.class.to_s, item_id: self.id).first
    pending_action.set_done if pending_action

    grading = self.get_final_grading
    if full_grade
      grading.grade = assessment.max_grade || 0
    else
      grading.update_grade
    end
    grading.save
    grading.exp
  end

  def build_initial_answers
    self.assessment.questions.includes(:as_question).each do |qn|
      if qn.is_a?(Assessment::MpqQuestion)
        qn.sub_questions.each do |sub|
          unless self.answers.find_by_question_id(sub.id)
            case
              when sub.is_a?(Assessment::GeneralQuestion)
                ans_class = Assessment::GeneralAnswer
              when sub.is_a?(Assessment::MpqQuestion)
                ans_class = Assessment::GeneralAnswer
              when sub.is_a?(Assessment::CodingQuestion)
                ans_class = Assessment::CodingAnswer
              when sub.is_a?(Assessment::McqQuestion)
                ans_class = Assessment::McqAnswer
              else
                ans_class = Assessment::GeneralAnswer
            end
            ans_class.create!({std_course_id: std_course_id,
                               question_id: sub.id,
                               #TODO, a acts_as_relation bug, parent can access children attributes, but respond_to return false
                               content: sub.specific.respond_to?(:template) ? sub.template : nil,
                               submission_id: self.id,
                               attempt_left: sub.attempt_limit})
          end
        end
      else
        unless self.answers.find_by_question_id(qn.id)
          case
            when qn.is_a?(Assessment::GeneralQuestion)
              ans_class = Assessment::GeneralAnswer
            when qn.is_a?(Assessment::MpqQuestion)
              ans_class = Assessment::GeneralAnswer
            when qn.is_a?(Assessment::CodingQuestion)
              ans_class = Assessment::CodingAnswer
            when qn.is_a?(Assessment::McqQuestion)
              ans_class = Assessment::McqAnswer
            else
              ans_class = Assessment::GeneralAnswer
          end
          ans_class.create!({std_course_id: std_course_id,
                           question_id: qn.id,
                           #TODO, a acts_as_relation bug, parent can access children attributes, but respond_to return false
                           content: qn.specific.respond_to?(:template) ? qn.template : nil,
                           submission_id: self.id,
                           attempt_left: qn.attempt_limit})
        end
      end

    end
  end

  def build_initial_answers_for_team sbm_list
    ans_voted = {}
    ans_stat = {}
    sbm_list.each do |ss_id,sbm|
      if !sbm.nil?
        sbm.answers.each do |ans|
          if ans.is_a? Assessment::GeneralAnswer and !ans.voted_answer_id.nil?
            ans_stat[ans.question_id] = {} if ans_stat[ans.question_id].nil?
            ans_stat[ans.question_id][ans.voted_answer_id]= ans_stat[ans.question_id][ans.voted_answer_id].nil? ? 1 : (ans_stat[ans.question_id][ans.voted_answer_id]+1)
          end
        end
      end
    end
    ans_stat.each do |ques_id, chosen_ans|
      curr_max = 0
      shuffle_arr = []
      chosen_ans.each do |ans_id, num_votes|
        curr_max = num_votes if num_votes > curr_max
      end
      chosen_ans.each do |ans_id, num_votes|
        shuffle_arr << ans_id if num_votes==curr_max
      end
      shuffle_arr.shuffle!
      ans_voted[ques_id] = shuffle_arr.count>0 ? shuffle_arr[0] : nil
    end
    self.assessment.questions.includes(:as_question).each do |qn|
      if qn.is_a?(Assessment::MpqQuestion)
        qn.sub_questions.each do |sub|
          unless self.answers.find_by_question_id(sub.id)
            case
              when sub.is_a?(Assessment::GeneralQuestion)
                ans_class = Assessment::GeneralAnswer
                if ans_voted[sub.id]
                  content = Assessment::Answer.find(ans_voted[sub.id]).content
                else
                  re_ans = sbm_list.values[Random.rand(sbm_list.count)].answers.where(question_id: sub.id).first
                  content = re_ans.content if re_ans
                end
              when sub.is_a?(Assessment::MpqQuestion)
                ans_class = Assessment::GeneralAnswer
              when sub.is_a?(Assessment::CodingQuestion)
                ans_class = Assessment::CodingAnswer
              when sub.is_a?(Assessment::McqQuestion)
                ans_class = Assessment::McqAnswer
              else
                ans_class = Assessment::GeneralAnswer
            end
            ans_class.create!({question_id: sub.id,
                               #TODO, a acts_as_relation bug, parent can access children attributes, but respond_to return false
                               content: content,
                               submission_id: self.id,
                               attempt_left: sub.attempt_limit})
          end
        end
      else
        unless self.answers.find_by_question_id(qn.id)
          case
            when qn.is_a?(Assessment::GeneralQuestion)
              ans_class = Assessment::GeneralAnswer
              if ans_voted[qn.id]
                content = Assessment::Answer.find(ans_voted[qn.id]).content
              else
                re_ans = sbm_list.values[Random.rand(sbm_list.count)].answers.where(question_id: qn.id).first
                content = re_ans.content if re_ans
              end
            when qn.is_a?(Assessment::MpqQuestion)
              ans_class = Assessment::GeneralAnswer
            when qn.is_a?(Assessment::CodingQuestion)
              ans_class = Assessment::CodingAnswer
            when qn.is_a?(Assessment::McqQuestion)
              ans_class = Assessment::McqAnswer
            else
              ans_class = Assessment::GeneralAnswer
          end
          ans_class.create!({question_id: qn.id,
                             #TODO, a acts_as_relation bug, parent can access children attributes, but respond_to return false
                             content: content,
                             submission_id: self.id,
                             attempt_left: qn.attempt_limit})
        end
      end

    end
  end

  def get_group_name
    if std_seats.count>0
      sg = std_seats.first.session.student_group
      "#{sg.name} - Group #{std_seats.first.table_number}"
    end
  end

  def get_group_sub_tutor
    if std_seats.count > 0 and std_seats.first.session.tutor
      return std_seats.first.session.tutor.name
    end
  end

  def fetch_params_answers(params)
    answers =  params[:answers] || []

    answers.each do |qid, ans|
      sa = self.answers.find_by_question_id(qid)
      sa.content = ans
      sa.save
    end

    sub_files = params[:files] ? params[:files].values : []
    self.attach_files(sub_files)
  end

  def attach_files(files)
    files.each do |id|
      file = FileUpload.find(id)
      file.owner = self
      file.save
    end
  end

  #Note that policy mission submissions must only have 1 open submission at one time
  def invalid_open_policy_mission_submission?
    psuedo_groups = self.progression_groups.where("is_completed = 0")
    psuedo_groups != 1
  end

  def getHighestProgressionGroupLevelName
    levelName = nil
    allProgressionGroups = self.progression_groups.where("is_completed = 1")
    allProgressionGroups.each do |progressionGroup|
		  forwardGroup = progressionGroup.getForwardGroup
		  forwardPolicyLevel = forwardGroup.getCorrespondingLevel
		  tag = forwardPolicyLevel.getTag
		  if progressionGroup.correct_amount_left == 0
			  levelName = tag.name
		  end
    end
    levelName
  end  

  #callbacks
  def status_change_tasks
    if assessment.is_mission? && status_was == 'attempting' && status == 'submitted'
      pending_action = std_course.pending_actions.where(item_type: Assessment.to_s, item_id: self.assessment.id).first
      pending_action.set_done if pending_action

      course = assessment.course
      if std_course.is_student? and course.email_notify_enabled?(PreferableItem.new_submission)
        Delayed::Job.enqueue(BackgroundJob.new(course, :new_submission, self.class.name.to_sym, self.id),
                             run_at: Time.now)
      end
    end
  end
end
