class CreateConceptEdges < ActiveRecord::Migration
  def change
    create_table :concept_edges do |t|
      t.integer :dependent_id
      t.integer :required_id

      t.timestamps
    end
  end
end
