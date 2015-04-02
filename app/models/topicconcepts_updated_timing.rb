class TopicconceptsUpdatedTiming < ActiveRecord::Base
  belongs_to :course  
  attr_accessible :course_id

  def set_updated_timing
    self.updated_at = Time.now
    self.save
  end

  def update_required timing
    self.updated_at >= timing 
  end
end
