class CreateTopicconceptsUpdatedTimings < ActiveRecord::Migration
  def up
  	create_table :topicconcepts_updated_timings do |t|
  	  t.references  :course, index: true

      t.timestamps
    end
  end

  def down
  	drop_table  :topicconcepts_updated_timings
  end
end
