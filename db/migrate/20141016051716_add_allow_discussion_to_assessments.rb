class AddAllowDiscussionToAssessments < ActiveRecord::Migration
  def change
    add_column :assessments, :allow_discussion, :boolean, :default => true
  end
end
