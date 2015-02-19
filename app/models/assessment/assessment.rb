class Assessment < ActiveRecord::Base
  acts_as_paranoid
  acts_as_duplicable
  #as is for belong_to association
  acts_as_superclass as: :as_assessment

  delegate :full_title, to: :as_assessment

  include Rails.application.routes.url_helpers

  default_scope { order("assessments.open_at") }

  attr_accessible :exp, :bonus_exp
  attr_accessible :title, :description
  attr_accessible :published, :comment_per_qn
  attr_accessible :open_at, :close_at, :bonus_cutoff_at
  attr_accessible :tab_id, :display_mode_id, :dependent_id
  attr_accessible :allow_discussion

  validates_presence_of :title


  include HasRequirement
  include ActivityObject

  scope :closed, -> { where("close_at < ?", Time.now) }
  scope :still_open, -> { where("close_at >= ? ", Time.now) }
  scope :opened, -> { where("open_at <= ? ", Time.now) }
  scope :future, -> { where("open_at > ? ", Time.now) }
  scope :published, -> { where(published: true) }
  scope :exclude_guidance_quiz, -> { where("as_assessment_type != ?", "Assessment::GuidanceQuiz") }
  scope :mission, -> { where(as_assessment_type: "Assessment::Mission") }
  scope :training, -> { where(as_assessment_type: "Assessment::Training") } do
    def retry_training
      joins("INNER JOIN assessment_trainings ON assessments.as_assessment_id = assessment_trainings.id")
      .where("assessment_trainings.test is null or assessment_trainings.test = 0")
    end
    def test
      joins("INNER JOIN assessment_trainings ON assessments.as_assessment_id = assessment_trainings.id")
      .where(:assessment_trainings => {:test => true})
    end
  end
	scope :policy_mission, -> { where(as_assessment_type: "Assessment::PolicyMission") }

  belongs_to  :tab
  belongs_to  :course
  belongs_to  :creator, class_name: "User"
  belongs_to  :display_mode, class_name: "AssignmentDisplayMode", foreign_key: "display_mode_id"
  belongs_to  :dependent_on, class_name: "Assessment", foreign_key: "dependent_id"

  has_many  :required_for, class_name: "Assessment", foreign_key: 'dependent_id'
  has_many  :as_asm_reqs, class_name: "AsmReq", as: :asm, dependent: :destroy
  has_many  :as_requirements, through: :as_asm_reqs, source: :as_requirements

  has_many  :question_assessments
  has_many  :questions, through: :question_assessments do
    def coding
      where(as_question_type: Assessment::CodingQuestion)
    end

    def mcq
      where(as_question_type: Assessment::McqQuestion)
    end

    #TODO
    def before(question, pos = 0)
      if question.persisted?
        before_pos(proxy_association.owner.question_assessments.where(question_id: question.id).first.position)
      else
        before_pos(pos)
      end
    end

    def before_pos(position)
      where('position < ?', position)
    end
  end
  
  has_many :taggable_tags, as: :taggable, dependent: :destroy
  has_many :tags, through: :questions
  has_many :topicconcepts, through: :questions


  has_many  :general_questions, class_name: "Assessment::GeneralQuestion",
            through: :questions,
            source: :as_question, source_type: "Assessment::GeneralQuestion"

  has_many  :mcqs, class_name: "Assessment::Question",
            through: :question_assessments,
            source: :question,
            conditions: {as_question_type: "Assessment::McqQuestion"}
  has_many  :files, as: :owner, class_name: "FileUpload", dependent: :destroy

  has_many  :queued_jobs, as: :owner, class_name: "QueuedJob", dependent: :destroy
  has_many  :pending_actions, as: :item, dependent: :destroy
  has_many  :submissions, class_name: "Assessment::Submission",dependent: :destroy, foreign_key: "assessment_id"

  amoeba do
    clone [:questions]
    include_field [:questions, :as_asm_reqs]
    # as_requirements
  end

  #callbacks
  before_update :clean_up_description, :if => :description_changed?
  after_save :update_opening_tasks, if: [:open_at_changed?, :published]
  after_save :update_closing_tasks, if: [:close_at_changed?, :published]
  after_save :create_or_destroy_tasks, if: :published_changed?



  def self.submissions
    Assessment::Submission.where(assessment_id: self.all)
  end

  def get_title
    full_title
  end

  def update_grade
    #self.update_attribute(:max_grade, self.questions.sum(&:max_grade))
  end

  def get_all_questions
    self.questions
  end

  def opened?
    open_at <= Time.now
  end

  def is_mission?
    as_assessment_type == Assessment::Mission.name
  end

  def is_training?
    as_assessment_type == Assessment::Training.name
  end

  def is_policy_mission?
    as_assessment_type == Assessment::PolicyMission.name
  end

  def is_guidance_quiz?
    as_assessment_type == Assessment::GuidanceQuiz.name
  end

  def getPolicyMission
    Assessment::PolicyMission.find(self.as_assessment_id)
  end

  def single_question?
    questions.count == 1
  end

  def last_submission(user_course_id)
    self.submissions.where(std_course_id: user_course_id).order(created_at: :desc).first
  end

  def get_final_sbm_by_std(std_course_id)
    self.submissions.find_by_std_course_id(std_course_id)
  end

  def get_qn_pos(qn)
    self.asm_qns.each_with_index do |asm_qn, i|
      if asm_qn.qn == qn
        return (asm_qn.pos || i) + 1
      end
    end
    -1
  end

  def update_qns_pos
    question_assessments.each_with_index do |qa, i|
      qa.position = i
      qa.save
    end
  end

  def get_path
		if is_policy_mission?
				course_assessment_policy_mission_path(self.course, self.specific)
		else
    	is_mission? ?
        	course_assessment_mission_path(self.course, self.specific) :
        	course_assessment_training_path(self.course, self.specific)
		end
  end

  #2014-12-18 refactoring from index method of assessment controller (line 50 - 87)
  def get_submission(course, user_course, manage_assessment)
    result = Hash.new
    sub = self.submissions.where(std_course_id: user_course.id).order('updated_at DESC').first
    dependent_ast_sub = self.dependent_on.nil? ? nil : self.dependent_on.submissions.where(std_course_id: user_course.id).order('updated_at DESC').first
    if sub
      result[:action] = sub.attempting? ? "Resume" : "Review"
      result[:url] = edit_course_assessment_submission_path(course, self, sub, from_lesson_plan: true)
    elsif (self.opened? and (self.as_assessment.class == Assessment::Training or
        self.dependent_id.nil? or self.dependent_id == 0 or
        (!dependent_ast_sub.nil? and !dependent_ast_sub.attempting?))) or
        manage_assessment
      result[:action] = "Attempt"
      result[:url] = new_course_assessment_submission_path(course, self, from_lesson_plan: true)
    else
      result[:action] = nil
    end
    result[:new] = false
    result[:opened] = self.opened?
    result[:published] = self.published
    result
  end

  def add_tags(tags)
    tags ||= []
    tags.each do |tag_id|
      self.asm_tags.build(
          tag_id: tag_id,
          max_exp: exp
      )
    end
    self.save
  end

  #TODO
  def can_start?(curr_user_course)
    if open_at > Time.now
      return false
    end
    if dependent_on
      sbm = assessment.submissions.where(assessment_id: dependent_id, std_course_id: curr_user_course).first
      if !sbm || sbm.attempting?
        return false
      end
    end
    true
  end

  def has_ended?
    return !self.close_at.nil? && self.close_at < Time.now
  end

  def can_access_with_end_check? (curr_user_course)
    if curr_user_course.is_staff?
      return true
    end
   
    return !has_ended?
  end

  #TOFIX: it's better to have callback rather than currently directly call this in
  #create. Can't use after_create because files association won't be updated upon save
  def create_local_file
    files.each do |file|
      PythonEvaluator.create_local_file_for_asm(self, file)
    end
  end

  #clean up messed html tags
  def clean_up_description
    self.description = CoursemologyFormatter.clean_code_block(description)
  end

  def dup_options(dup_files = true)
    clone = dup
    clone.save
    if dup_files
      files.each do |file|
        file.dup_owner(clone)
      end
      folder_path = PythonEvaluator.get_asm_file_path(self)
      if File.exist? folder_path
        copy_path = PythonEvaluator.get_asm_file_path(clone)
        FileUtils.mkdir_p(copy_path) unless File.exist?(copy_path)
        FileUtils.cp_r(folder_path + "." , copy_path)
      end
    end
    clone
  end

  def mark_refresh_autograding
    Thread.new {
      submissions.each do |s|
        s.gradings.each do |sg|
          sg.update_attribute(:autograding_refresh, true)
        end
      end
    }
  end

  def current_exp
    exp
  end

  def dup
    s = self.specific
    d = s.dup
    asm = super
    d.assessment = asm
    asm.as_assessment = d
    asm
  end

  def attach_files(files)
    files.each do |id|
      file = FileUpload.find id
      if file
        file.owner = self
        file.save
      end
    end
  end

  #callbacks
  def update_opening_tasks
    if is_guidance_quiz?
      return
    end

    #1. pending actions
    #2. auto submission
    #3. email notifications
    tks = {pending_action: true,
           auto_submission:  (is_mission? || is_policy_mission?)  && course.auto_create_sbm_pref.enabled?,
           notification: self.open_at >= Time.now &&
               course.email_notify_enabled?(PreferableItem.new_assessment(as_assessment_type.constantize)) }

    tks.each do |type, condition|
      next unless condition
      create_delayed_job(type, self.open_at)
    end
  end

  def update_closing_tasks
    if is_guidance_quiz?
      return
    end

    #1. remainder
    type = :mission_due
    if (is_mission? || is_policy_mission?) and self.close_at >= Time.now and course.email_notify_enabled?(type.to_s)
      create_delayed_job(type, 1.day.ago(self.close_at))
    end
  end

  def create_delayed_job(type, run_at)
    self.queued_jobs.where(job_type: type).destroy_all
    delayed_job = Delayed::Job.enqueue(BackgroundJob.new(course, type, Assessment.to_s.to_sym, self.id),
                                       run_at: run_at)
    self.queued_jobs.create({delayed_job_id: delayed_job.id, job_type: type})
  end

  def create_or_destroy_tasks
    if is_guidance_quiz?
      return
    end

    if published?
      update_opening_tasks
      update_closing_tasks
    else
      self.queued_jobs.destroy_all
    end
  end
end

