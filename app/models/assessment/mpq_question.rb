class Assessment::MpqQuestion < ActiveRecord::Base
  acts_as_paranoid
  is_a :question, as: :as_question, class_name: "Assessment::Question"

  has_many  :children, class_name: Assessment::MpqSubQuestion, dependent: :destroy, foreign_key: "parent_id"
  has_many :sub_questions, :through => :children, class_name: Assessment::Question, dependent: :destroy, :source => :child


end
