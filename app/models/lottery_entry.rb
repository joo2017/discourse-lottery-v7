# frozen_string_literal: true

class LotteryEntry < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user
  belongs_to :image_upload, class_name: 'Upload', optional: true

  validates :title, presence: true
  validates :prize_description, presence: true
  validates :draw_time, presence: true
  validates :winner_count, presence: true, numericality: { greater_than: 0 }
  validates :min_participants, presence: true, numericality: { greater_than: 0 }
  validates :backup_strategy, presence: true, inclusion: { in: %w[continue cancel] }
  validates :lottery_type, presence: true, inclusion: { in: %w[random specified] }
  validates :status, presence: true, inclusion: { in: %w[running finished cancelled] }

  scope :running, -> { where(status: 'running') }
  scope :finished, -> { where(status: 'finished') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :due_for_draw, -> { where('draw_time <= ? AND status = ?', Time.current, 'running') }

  # 移除旧的 serialize 语法，直接使用 jsonb 字段
  # serialize :winners_data, JSON  # 删除这行

  def specified_floors_array
    return [] unless specified_floors.present?
    specified_floors.split(',').map(&:strip).map(&:to_i)
  end

  def winners
    return [] unless winners_data.present?
    
    user_ids = winners_data.map { |w| w['user_id'] }
    users = User.where(id: user_ids).index_by(&:id)
    
    winners_data.map do |winner_data|
      user = users[winner_data['user_id']]
      next unless user
      
      {
        user: user,
        username: winner_data['username'],
        floor: winner_data['floor'],
        post_id: winner_data['post_id']
      }
    end.compact
  end

  def can_edit?
    return false unless status == 'running'
    lock_time = draw_time - SiteSetting.lottery_post_lock_delay_minutes.minutes
    Time.current < lock_time
  end

  def participants_count
    return 0 unless topic
    excluded_groups = SiteSetting.lottery_excluded_groups.split('|')
    excluded_user_ids = Group.where(name: excluded_groups).joins(:users).pluck('group_users.user_id')
    
    topic.posts.where.not(user_id: user_id)
         .where.not(user_id: excluded_user_ids)
         .where(deleted_at: nil, hidden: false)
         .group(:user_id)
         .count
         .size
  end
end
