class AddModuleIdToCourses < ActiveRecord::Migration
  def change
    add_column :courses, :module_id, :string
  end
end
