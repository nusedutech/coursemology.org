class AddTagTypeToTaggableTags < ActiveRecord::Migration
  def change
    add_column :taggable_tags, :tag_type, :string
  end
end
