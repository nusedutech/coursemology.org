#This class will be maintained as a single member class. However, as it is inherited from a collection
#based model (assessment), it is treated as such
class Assessment::GuidanceQuiz < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

  attr_accessible :published

  def self.is_enabled? (course)
    course && course.guidance_quizzes && course.guidance_quizzes.first && course.guidance_quizzes.first.published == true
  end

  def self.enable (course)
    if course && course.guidance_quizzes && course.guidance_quizzes.first
      @guidance_quiz = course.guidance_quizzes.first
    else
      @guidance_quiz = Assessment::GuidanceQuiz.new
      @guidance_quiz.title = "standard"
      @guidance_quiz.course = course
    end
    
    @guidance_quiz.published = true
    @guidance_quiz.save
  end

  def self.disable (course)
    if course && course.guidance_quizzes && course.guidance_quizzes.first
      @guidance_quiz = course.guidance_quizzes.first
      @guidance_quiz.published = false
      @guidance_quiz.save
    end
  end
end
