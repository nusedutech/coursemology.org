class AddDefaultValueToMaxGradeAssessments < ActiveRecord::Migration
  def change
    change_column :assessments, :max_grade, :float, :default => 0
  end
end
