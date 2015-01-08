class TaggableTag < ActiveRecord::Base
  acts_as_duplicable

  attr_accessible :taggable_id
  belongs_to  :taggable, polymorphic: true
  belongs_to  :tag, polymorphic: true
  #belongs_to  :taggable, polymorphic: true
  #belongs_to  :tag
  belongs_to  :question, class_name: "Assessment::Question"
end
