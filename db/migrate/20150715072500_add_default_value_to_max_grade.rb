class AddDefaultValueToMaxGrade < ActiveRecord::Migration
  def change
    change_column :assessment_questions, :max_grade, :float, :default => 0
  end
end
