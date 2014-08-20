class CreateTopicconcepts < ActiveRecord::Migration
  def change
    create_table :topicconcepts do |t|
      t.string :name, :limit => 300
      t.text :description
      t.string :typename, :limit => 50
      t.integer :course_id
      t.string :rank, :limit => 50
      t.time :deleted_at

      t.timestamps
    end
  end
end
