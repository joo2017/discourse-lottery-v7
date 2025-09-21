# frozen_string_literal: true

class CreateLotteryEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :lottery_entries do |t|
      t.bigint :topic_id, null: false
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.text :prize_description, null: false
      t.bigint :image_upload_id
      t.datetime :draw_time, null: false
      t.integer :winner_count, null: false
      t.text :specified_floors
      t.integer :min_participants, null: false
      t.string :backup_strategy, null: false
      t.text :additional_notes
      t.string :lottery_type, null: false
      t.string :status, null: false, default: 'running'
      t.jsonb :winners_data, default: []  # 直接使用 jsonb 类型
      t.timestamps null: false
    end

    add_index :lottery_entries, :topic_id, unique: true
    add_index :lottery_entries, :user_id
    add_index :lottery_entries, :draw_time
    add_index :lottery_entries, :status
    add_index :lottery_entries, [:status, :draw_time]
  end
end
