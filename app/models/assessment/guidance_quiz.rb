#This class will be maintained as a single member class. However, as it is inherited from a collection
#based model (assessment), it is treated as such
class Assessment::GuidanceQuiz < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

  attr_accessible :published, :passing_edge_lock, :neighbour_entry_lock
 
  def enabled
    self.published
  end

  def self.is_enabled? (course)
    course && course.guidance_quizzes && course.guidance_quizzes.first && course.guidance_quizzes.first.published
  end

  def self.is_neighbour_entry_lock? (course)
    course && course.guidance_quizzes && course.guidance_quizzes.first && course.guidance_quizzes.first.neighbour_entry_lock
  end

  def self.is_passing_edge_lock? (course)
    course && course.guidance_quizzes && course.guidance_quizzes.first && course.guidance_quizzes.first.passing_edge_lock
  end

  def self.enable (course)
    self.create_if_new (course)
    @guidance_quiz.published = true
    @guidance_quiz.save
  end

  def self.disable (course)
    self.create_if_new (course)
    @guidance_quiz.published = false
    @guidance_quiz.save
  end

  def self.set_passing_edge_lock (course, bool_value)
    self.create_if_new (course)
    @guidance_quiz.passing_edge_lock = bool_value
    @guidance_quiz.save
  end

  def self.set_neighbour_entry_lock (course, bool_value)
    self.create_if_new (course)
    @guidance_quiz.neighbour_entry_lock = bool_value
    @guidance_quiz.save
  end

  #Create the course if it is not created yet
  def self.create_if_new (course)
    if course && course.guidance_quizzes && course.guidance_quizzes.first
      @guidance_quiz = course.guidance_quizzes.first
      if course.guidance_quizzes.length > 1
        course.guidance_quizzes.where('assessment_guidance_quizzes.id != ?', @guidance_quiz.id).destroy_all  
      end
    else
      @guidance_quiz = Assessment::GuidanceQuiz.new
      @guidance_quiz.title = "standard"
      @guidance_quiz.course = course
      @guidance_quiz.save
    end

    @guidance_quiz
  end

  def self.get_guidance_quiz (course)
    course.guidance_quizzes.first
  end
end
