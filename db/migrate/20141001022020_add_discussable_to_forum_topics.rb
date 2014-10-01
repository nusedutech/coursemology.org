class AddDiscussableToForumTopics < ActiveRecord::Migration
  def change
    add_column :forum_topics, :discussable_type, :string
    add_column :forum_topics, :discussable_id, :integer
  end
end
