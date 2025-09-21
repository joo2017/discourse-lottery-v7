# frozen_string_literal: true

class CreateLotteryEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :lottery_entries do |t|
      t.integer :topic_id, null: false
      t.integer :user_id, null: false
      t.string :title, null: false
      t.text :prize_description, null: false
      t.integer :image_upload_id
      t.datetime :draw_time, null: false
      t.integer :winner_count, null: false
      t.string :specified_floors
      t.integer :min_participants, null: false
      t.string :backup_strategy, null: false
      t.text :additional_notes
      t.string :lottery_type, null: false
      t.string :status, default: 'running', null: false
      t.json :winners_data
      t.timestamps null: false
    end

    add_index :lottery_entries, :topic_id, unique: true
    add_index :lottery_entries, :user_id
    add_index :lottery_entries, :draw_time
    add_index :lottery_entries, :status
    add_index :lottery_entries, [:status, :draw_time]
  end
end
