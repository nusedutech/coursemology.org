class Assessment::Question < ActiveRecord::Base
  acts_as_paranoid
  acts_as_duplicable
  acts_as_superclass as: :as_question
  acts_as_taggable

  attr_accessible :creator_id, :dependent_id
  attr_accessible :title, :description, :max_grade, :attempt_limit, :staff_comments
  attr_accessible :auto_graded

  scope :general_question, -> { where(as_question_type: "Assessment::GeneralQuestion") }
  scope :coding_question, -> { where(as_question_type: "Assessment::CodingQuestion") }
  scope :mcq_question, -> { where(as_question_type: "Assessment::McqQuestion") }
  scope :mpq_question, -> { where(as_question_type: "Assessment::MpqQuestion") }
  scope :general_and_coding_question, -> { where(as_question_type: ["Assessment::GeneralQuestion", "Assessment::CodingQuestion"]) }
  scope :mcq_and_coding_question, -> { where(as_question_type: ["Assessment::McqQuestion", "Assessment::CodingQuestion"]) }

  belongs_to  :course
  belongs_to  :creator, class_name: "User"
  belongs_to  :dependent_on, class_name: "Assessment::Question", foreign_key: "dependent_id"


  #TODO, dependent: :destroy here
  has_many  :question_assessments, dependent: :destroy
  has_many  :answers, class_name: Assessment::Answer, dependent: :destroy
  has_many  :answer_gradings, class_name: Assessment::AnswerGrading, through: :answers
  has_one   :comment_topic, as: :topic
  
  has_many :taggable_tags, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggable_tags, source: :tag, source_type: "Tag"
  has_many :topicconcepts, through: :taggable_tags, source: :tag, source_type: "Topicconcept"

  has_one :exclusion_status, class_name: Assessment::GuidanceQuizExcludedQuestion, dependent: :destroy
  
  before_update :clean_up_description, :if => :description_changed?
  after_update  :update_assessment_grade, if: :max_grade_changed?
  after_update  :update_attempt_limit, if: :attempt_limit_changed?

  def self.import (file, current_user, course)
    csv_text = File.read(file.path)
    csv = CSV.parse(csv_text, :headers => true)

    error_list = []
    obj_list = []
    csv.each_with_index do |row, index|
      error_sms = String.new
      if (!row["max_grade"].nil? && !(true if Integer(row["max_grade"]) rescue false))
        error_sms << "max_grade empty,"
      elsif row["option1"].nil?
        attrs = {"creator_id"=> current_user.id, "title" => row["title"], "description" => row["description"], "max_grade"=> row["max_grade"]}
        g_ques = Assessment::GeneralQuestion.new(attrs)
        g_ques.course = course
        obj_list << g_ques
        if !row["tags"].nil?
          row["tags"].split('|').each do |tag|
            tag_element = course.topicconcepts.where(:name => tag).first
            if(!tag_element.nil?)
              taggable = g_ques.question.taggable_tags.new
              taggable.tag = tag_element
              obj_list << taggable
            else
              error_sms << "tag #{tag} not exist,"
            end
          end
        end
        if !row["difficulty"].nil?
          diff = course.tags.where(:name => row["difficulty"]).first
          if(!diff.nil?)
            taggable = g_ques.question.taggable_tags.new
            taggable.tag = diff
            obj_list << taggable
          end
        end
      else
        if (!row["select_all"].nil? && !(true if Integer(row["select_all"]) rescue false))
          error_sms << "select_all invalid,"
        else
          attrs = {"creator_id"=> current_user.id, "title" => row["title"], "description" => row["description"], "max_grade"=> row["max_grade"], "select_all" => row["select_all"].nil? ? 0 : row["select_all"].to_i}
          mcq_ques = Assessment::McqQuestion.new(attrs)
          mcq_ques.course = course
          obj_list << mcq_ques
          (1..10).each do |i|
            if !row["option#{i}"].nil?
              opt_attrs = {"text"=> row["option#{i}"], "explanation" => row["explanation#{i}"], "correct" => row["correct#{i}"].to_i}
              mcq_opt = Assessment::McqOption.new(opt_attrs)
              mcq_opt.question = mcq_ques
              obj_list << mcq_opt
            end
          end
          if !row["tags"].nil?
            row["tags"].split('|').each do |tag|
              tag_element = course.topicconcepts.where(:name => tag).first
              if(!tag_element.nil?)
                taggable = mcq_ques.question.taggable_tags.new
                taggable.tag = tag_element
                obj_list << taggable
              else
                error_sms << "tag #{tag} not exist,"
              end
            end
          end
          if !row["difficulty"].nil?
            diff = course.tags.where(:name => row["difficulty"]).first
            if(!diff.nil?)
              taggable = mcq_ques.question.taggable_tags.new
              taggable.tag = diff
              obj_list << taggable
            end
          end
        end
      end
      if !error_sms.empty?
        error_list << ("Row #{index + 2}: " + error_sms[0..-2]);
      end
    end

    #File.delete(file.path)
    if error_list.empty?
      obj_list.each do |o|
        o.save
      end
      return {:flag => true, :info => "Imported #{csv.count} questions"}
    else
      return {:flag => false, :info => "There are somethings wrong: </br>" + error_list.join("</br>")}
    end
  end


  def self check_before_import_question

  end


  #TOFIX
  def get_title
    title && !title.empty? ? title : "Question #{question_assessments.first.position}"
  end

  def get_title_for_nil
    title && !title.nil? ? ' - ' +  title : ""
  end

  #callback methods

  def clean_up_description
    self.description = CoursemologyFormatter.clean_code_block(description)
  end

  def update_assessment_grade
    puts "update grade", self.question_assessments.count
    self.question_assessments.each do |qa|
      qa.assessment.update_grade
    end
  end

  def update_attempt_limit
    old_tl = changed_attributes[:attempt_limit] || 0
    diff = attempt_limit - old_tl
    if diff != 0
      Thread.start {
        answers.each do |sa|
          sa.attempt_left = [0, sa.attempt_left + diff].max
          sa.save
        end
      }
    end
  end

  def existingAssessments
    if self and self.id
      Assessment.joins("LEFT JOIN  question_assessments ON question_assessments.assessment_id = assessments.id")
      .where("question_assessments.question_id = ?", self.id).uniq
    else
      []
    end
  end

  def relatedAnswers
    if self and self.id
      Assessment::Answer.where(question_id: self.id)
    end
  end

  def self.assessments
    Assessment.joins("LEFT JOIN  question_assessments ON question_assessments.assessment_id = assessments.id")
    .where("question_assessments.question_id IN (?)", self.all).uniq
  end

  #TODO: i hope mysql is smart enough to optimize this
  #finalise for normal training or old training (one kind of traning, allow come back questions)
  def self.finalised(sbm)
    grouped_answers = "SELECT *, MIN(created_at)
                      FROM assessment_answers
                      WHERE assessment_answers.finalised = 1 and assessment_answers.submission_id = #{sbm.id}
                      GROUP BY  assessment_answers.question_id"
    self.joins("INNER JOIN (#{grouped_answers}) uaaq ON assessment_questions.id = uaaq.question_id")
  end

  #finalise for test (one kind of traning)
  def self.finalised_for_test(sbm)
    #new code for normal training
    grouped_answers = "SELECT *, MIN(created_at)
                      FROM assessment_answers
                      WHERE assessment_answers.submission_id = #{sbm.id}
                      GROUP BY  assessment_answers.question_id"
    self.joins("INNER JOIN (#{grouped_answers}) uaaq ON assessment_questions.id = uaaq.question_id")
  end
  #overrides
  def dup
    s = self.specific
    d = s.amoeba_dup
    qn = super
    d.question = qn
    qn.as_question = d
    qn
  end
end
