class AddGroupIdToLessonPlanEntries < ActiveRecord::Migration
  def change
    add_column :lesson_plan_entries, :group_id, :integer
  end
end
