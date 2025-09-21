# frozen_string_literal: true

class LotteryEntry < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user
  belongs_to :image_upload, class_name: 'Upload', optional: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :prize_description, presence: true
  validates :draw_time, presence: true
  validates :winner_count, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :min_participants, presence: true, numericality: { greater_than: 0 }
  validates :backup_strategy, presence: true, inclusion: { in: %w[continue cancel] }
  validates :lottery_type, presence: true, inclusion: { in: %w[random specified] }
  validates :status, presence: true, inclusion: { in: %w[running finished cancelled] }

  scope :running, -> { where(status: 'running') }
  scope :finished, -> { where(status: 'finished') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :due_for_draw, -> { where('draw_time <= ? AND status = ?', Time.current, 'running') }

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

  def time_until_draw
    return 0 if draw_time <= Time.current
    (draw_time - Time.current).to_i
  end

  def time_until_lock
    return 0 unless can_edit?
    
    lock_time = draw_time - SiteSetting.lottery_post_lock_delay_minutes.minutes
    return 0 if lock_time <= Time.current
    
    (lock_time - Time.current).to_i
  end

  def participants_count
    return 0 unless topic
    
    excluded_groups = SiteSetting.lottery_excluded_groups.split('|')
    
    # 计算有效参与者
    topic.posts.joins(:user)
         .where.not(user_id: user_id)
         .where(deleted_at: nil, hidden: false)
         .where.not(users: { id: Group.where(name: excluded_groups).joins(:users).select('group_users.user_id') })
         .group(:user_id)
         .count
         .size
  end

  def meets_minimum_participants?
    participants_count >= min_participants
  end
end
