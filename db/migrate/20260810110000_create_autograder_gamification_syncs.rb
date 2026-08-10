# frozen_string_literal: true

class CreateAutograderGamificationSyncs < ActiveRecord::Migration[8.0]
  def change
    create_table :autograder_gamification_syncs do |t|
      t.integer :user_id, null: false
      t.integer :gamification_score_event_id, null: false
      t.integer :points, null: false, default: 0

      t.timestamps
    end

    add_index :autograder_gamification_syncs, :user_id, unique: true
    add_index :autograder_gamification_syncs, :gamification_score_event_id, unique: true
  end
end
