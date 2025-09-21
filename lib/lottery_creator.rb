# frozen_string_literal: true

class LotteryCreator
  include ActiveModel::Model

  attr_accessor :topic, :user

  def initialize(topic:, user:)
    @topic = topic
    @user = user
  end

  def create
    return failure("抽奖功能未启用") unless SiteSetting.lottery_enabled
    return failure("缺少必要的抽奖信息") unless validate_required_fields
    return failure("参与门槛不能低于 #{SiteSetting.lottery_min_participants_global} 人") unless validate_min_participants
    return failure("开奖时间必须是未来时间") unless validate_draw_time

    # 智能判断抽奖方式
    lottery_type, winner_count, specified_floors = determine_lottery_type

    # 更新主题自定义字段
    update_topic_fields(lottery_type, winner_count, specified_floors)

    # 调度任务
    schedule_jobs

    # 添加标签
    add_lottery_tag

    success("抽奖创建成功")
  rescue => e
    Rails.logger.error "LotteryCreator error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure("系统错误: #{e.message}")
  end

  private

  def validate_required_fields
    required_fields = %w[
      lottery_title
      lottery_prize_description  
      lottery_draw_time
      lottery_winner_count
      lottery_min_participants
      lottery_backup_strategy
    ]
    
    required_fields.all? { |field| topic.custom_fields[field].present? }
  end

  def validate_min_participants
    min_participants = topic.custom_fields["lottery_min_participants"].to_i
    min_participants >= SiteSetting.lottery_min_participants_global
  end

  def validate_draw_time
    draw_time = Time.parse(topic.custom_fields["lottery_draw_time"])
    draw_time > Time.current
  rescue
    false
  end

  def determine_lottery_type
    specified_floors = topic.custom_fields["lottery_specified_floors"]
    
    if specified_floors.present?
      floors = specified_floors.split(',').map(&:strip).map(&:to_i).select(&:positive?)
      if floors.any?
        return ["specified", floors.size, floors.join(',')]
      end
    end
    
    ["random", topic.custom_fields["lottery_winner_count"].to_i, nil]
  end

  def update_topic_fields(lottery_type, winner_count, specified_floors)
    topic.custom_fields["lottery_type"] = lottery_type
    topic.custom_fields["lottery_winner_count"] = winner_count
    topic.custom_fields["lottery_specified_floors"] = specified_floors if specified_floors
    topic.custom_fields["lottery_status"] = "running"
    topic.save_custom_fields
  end

  def schedule_jobs
    draw_time = Time.parse(topic.custom_fields["lottery_draw_time"])
    
    # 调度开奖任务
    Jobs.enqueue_at(draw_time, :execute_lottery_draw, {
      topic_id: topic.id
    })

    # 调度锁定任务
    lock_time = draw_time - SiteSetting.lottery_post_lock_delay_minutes.minutes
    if lock_time > Time.current
      Jobs.enqueue_at(lock_time, :lock_lottery_post, {
        topic_id: topic.id
      })
    end
  end

  def add_lottery_tag
    tag = Tag.find_or_create_by(name: "抽奖中")
    topic.tags << tag unless topic.tags.include?(tag)
  end

  def success(message)
    { success: true, message: message }
  end

  def failure(message)
    # 发送系统通知给用户
    PostCreator.create!(
      Discourse.system_user,
      topic_id: topic.id,
      raw: "@#{user.username} 抽奖创建失败：#{message}。请检查设置后重新尝试。"
    )
    
    { success: false, error: message }
  end
end
