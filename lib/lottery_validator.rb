# frozen_string_literal: true

class LotteryValidator
  include ActiveModel::Model

  attr_accessor :params, :user, :topic

  validate :lottery_enabled
  validate :required_fields_present
  validate :min_participants_valid
  validate :draw_time_valid
  validate :winner_count_valid
  validate :backup_strategy_valid
  validate :specified_floors_valid
  validate :user_permissions

  def initialize(params:, user:, topic: nil)
    @params = params
    @user = user
    @topic = topic
  end

  def validate!
    valid? || raise(ActiveRecord::RecordInvalid.new(self))
  end

  private

  def lottery_enabled
    unless SiteSetting.lottery_enabled
      errors.add(:base, "抽奖功能未启用")
    end
  end

  def required_fields_present
    required_fields = %w[
      lottery_title
      lottery_prize_description
      lottery_draw_time
      lottery_winner_count
      lottery_min_participants
      lottery_backup_strategy
    ]

    required_fields.each do |field|
      if params[field].blank?
        field_name = field.gsub('lottery_', '').humanize
        errors.add(field.to_sym, "#{field_name}不能为空")
      end
    end
  end

  def min_participants_valid
    min_participants = params[:lottery_min_participants].to_i
    global_min = SiteSetting.lottery_min_participants_global

    if min_participants < global_min
      errors.add(:lottery_min_participants, "参与门槛不能低于 #{global_min} 人")
    end
  end

  def draw_time_valid
    begin
      draw_time = Time.parse(params[:lottery_draw_time])
      if draw_time <= Time.current
        errors.add(:lottery_draw_time, "开奖时间必须是未来时间")
      end
    rescue ArgumentError
      errors.add(:lottery_draw_time, "开奖时间格式无效")
    end
  end

  def winner_count_valid
    winner_count = params[:lottery_winner_count].to_i
    
    if winner_count < 1
      errors.add(:lottery_winner_count, "获奖人数必须大于0")
    elsif winner_count > 100
      errors.add(:lottery_winner_count, "获奖人数不能超过100")
    end
  end

  def backup_strategy_valid
    valid_strategies = %w[continue cancel]
    
    unless valid_strategies.include?(params[:lottery_backup_strategy])
      errors.add(:lottery_backup_strategy, "后备策略必须是 'continue' 或 'cancel'")
    end
  end

  def specified_floors_valid
    return unless params[:lottery_specified_floors].present?
    
    floors_str = params[:lottery_specified_floors].strip
    return if floors_str.blank?
    
    begin
      floors = floors_str.split(',').map(&:strip).map(&:to_i)
      
      floors.each do |floor|
        if floor < 2
          errors.add(:lottery_specified_floors, "楼层号必须大于等于2（不能包含楼主）")
          break
        end
      end
      
      if floors.uniq.size != floors.size
        errors.add(:lottery_specified_floors, "楼层号不能重复")
      end
      
    rescue ArgumentError
      errors.add(:lottery_specified_floors, "楼层号格式无效，请使用逗号分隔的数字")
    end
  end

  def user_permissions
    return unless topic
    
    # 检查用户是否有在指定分类创建主题的权限
    if SiteSetting.lottery_category_ids.present?
      allowed_categories = SiteSetting.lottery_category_ids.split('|').map(&:to_i)
      unless allowed_categories.include?(topic.category_id)
        errors.add(:base, "该分类不允许创建抽奖")
      end
    end
    
    # 检查用户是否被禁止参与抽奖
    excluded_groups = SiteSetting.lottery_excluded_groups.split('|')
    user_groups = user.groups.pluck(:name)
    
    if (user_groups & excluded_groups).any?
      errors.add(:base, "您所在的用户组不允许创建抽奖")
    end
  end
end
