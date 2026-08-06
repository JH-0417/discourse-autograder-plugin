# frozen_string_literal: true

class CreateAutograderSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :autograder_submissions do |t|
      t.integer :user_id, null: false
      t.integer :category_id, null: false
      t.integer :topic_id, null: false
      t.integer :post_id, null: false
      t.integer :upload_id
      t.string :status, null: false, default: "queued"
      t.decimal :score, precision: 10, scale: 6
      t.decimal :auc, precision: 10, scale: 6
      t.decimal :precision_score, precision: 10, scale: 6
      t.decimal :brier_score, precision: 10, scale: 6
      t.text :message
      t.json :result_data
      t.timestamps
    end

    add_index :autograder_submissions, :post_id, unique: true
    add_index :autograder_submissions, [:user_id, :topic_id]
    add_index :autograder_submissions, [:category_id, :status]
  end
end
