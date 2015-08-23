class AddTutorIdToStudentGroups < ActiveRecord::Migration
  def change
    add_column :student_groups, :tutor_id, :integer
  end
end
