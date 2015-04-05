class AddRatingColumnToTagsTable < ActiveRecord::Migration
  def change
  	add_column :tags, :rating, :integer, default: 1
  end
end
