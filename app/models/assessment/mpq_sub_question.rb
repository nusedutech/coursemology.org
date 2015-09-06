class Assessment::MpqSubQuestion < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :parent, class_name: Assessment::MpqQuestion
  belongs_to :child, class_name: Assessment::Question

  after_destroy :update_parent_grade

  def update_parent_grade
    parent.update_max_grade
  end
end
