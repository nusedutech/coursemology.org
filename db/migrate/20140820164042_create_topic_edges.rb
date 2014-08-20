class CreateTopicEdges < ActiveRecord::Migration
  def change
    create_table :topic_edges do |t|
      t.integer :parent_id
      t.integer :included_topic_concept_id

      t.timestamps
    end
  end
end
