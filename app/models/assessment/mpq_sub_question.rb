class Assessment::MpqSubQuestion < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :parent, class_name: Assessment::MpqQuestion
  belongs_to :child, class_name: Assessment::Question
end
