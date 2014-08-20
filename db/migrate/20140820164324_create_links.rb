class CreateLinks < ActiveRecord::Migration
  def change
    create_table :links do |t|
      t.integer :concept_id
      t.string :link, :limit => 300
      t.time :deleted_at

      t.timestamps
    end
  end
end
