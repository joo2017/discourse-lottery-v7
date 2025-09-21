# frozen_string_literal: true

class LotteryManager
  include ActiveModel::Model

  attr_accessor :lottery_entry

  def initialize(lottery_entry:)
    @lottery_entry = lottery_entry
  end

  def execute_draw
    Rails.logger.info "开始执行抽奖 ##{lottery_entry.id}"
    
    return failure("抽奖已结束") unless lottery_entry.status == 'running'
    
    # 计算有效参与人数
    valid_participants = calculate_valid_participants
    Rails.logger.info "有效参与人数: #{valid_participants.size}"
    
    # 判断是否满足条件
    if valid_participants.size >= lottery_entry.min_participants
      execute_lottery_process(valid_participants)
    else
      handle_insufficient_participants(valid_participants)
    end
    
  rescue => e
    Rails.logger.error "抽奖执行错误: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    cancel_lottery("系统错误: #{e.message}")
  end

  private

  def calculate_valid_participants
    topic = lottery_entry.topic
    excluded_groups = SiteSetting.lottery_excluded_groups.split('|')
    
    # 获取所有回复（排除楼主）
    replies = topic.posts.where.not(user_id: lottery_entry.user_id)
                   .where(deleted_at: nil, hidden: false)
                   .includes(:user)
    
    valid_users = []
    user_posts = {}
    
    replies.each do |post|
      user = post.user
      next if user.nil?
      
      # 排除特定用户组
      user_groups = user.groups.pluck(:name)
      next if (user_groups & excluded_groups).any?
      
      # 每个用户只取最早的回复
      unless user_posts[user.id]
        user_posts[user.id] = post
        valid_users << {
          user: user,
          post: post,
          floor: post.post_number
        }
      end
    end
    
    valid_users.sort_by { |p| p[:post].created_at }
  end

  def execute_lottery_process(valid_participants)
    if lottery_entry.lottery_type == 'specified'
      execute_specified_floor_lottery(valid_participants)
    else
      execute_random_lottery(valid_participants)
    end
  end

  def execute_specified_floor_lottery(valid_participants)
    specified_floors = lottery_entry.specified_floors.split(',').map(&:to_i)
    winners = []
    
    specified_floors.each do |floor_num|
      participant = valid_participants.find { |p| p[:floor] == floor_num }
      if participant
        winners << participant
      else
        Rails.logger.warn "指定楼层 #{floor_num} 无效或不符合参与条件"
      end
    end
    
    if winners.any?
      finish_lottery(winners)
    else
      cancel_lottery("所有指定楼层都无效")
    end
  end

  def execute_random_lottery(valid_participants)
    if valid_participants.size < lottery_entry.winner_count
      # 参与人数少于中奖人数，全部中奖
      winners = valid_participants
    else
      # 随机抽取指定数量的中奖者
      winners = valid_participants.sample(lottery_entry.winner_count)
    end
    
    finish_lottery(winners)
  end

  def handle_insufficient_participants(valid_participants)
    if lottery_entry.backup_strategy == 'continue'
      Rails.logger.info "参与人数不足，但选择继续开奖"
      execute_lottery_process(valid_participants)
    else
      cancel_lottery("参与人数不足（需要 #{lottery_entry.min_participants} 人，实际 #{valid_participants.size} 人）")
    end
  end

  def finish_lottery(winners)
    # 保存中奖者数据
    winners_data = winners.map do |winner|
      {
        user_id: winner[:user].id,
        username: winner[:user].username,
        floor: winner[:floor],
        post_id: winner[:post].id
      }
    end
    
    lottery_entry.update!(
      status: 'finished',
      winners_data: winners_data
    )
    
    # 更新主题状态
    topic = lottery_entry.topic
    topic.custom_fields["lottery_status"] = "finished"
    topic.save_custom_fields
    
    # 发布中奖公告
    announce_winners(winners)
    
    # 发送私信通知
    send_winner_notifications(winners)
    
    # 更新标签
    update_topic_tags("已开奖")
    
    # 锁定主题
    lock_topic
    
    Rails.logger.info "抽奖完成，共 #{winners.size} 人中奖"
  end

  def cancel_lottery(reason)
    lottery_entry.update!(status: 'cancelled')
    
    # 更新主题状态
    topic = lottery_entry.topic
    topic.custom_fields["lottery_status"] = "cancelled"
    topic.save_custom_fields
    
    # 发布取消公告
    announce_cancellation(reason)
    
    # 更新标签
    update_topic_tags("已取消")
    
    Rails.logger.info "抽奖已取消: #{reason}"
  end

  def announce_winners(winners)
    winner_list = winners.map.with_index(1) do |winner, index|
      "#{index}. @#{winner[:user].username} (#{winner[:floor]}楼)"
    end.join("\n")
    
    announcement = <<~TEXT
      🎉 **抽奖结果公布** 🎉
      
      **活动名称：** #{lottery_entry.title}
      **开奖时间：** #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
      **中奖名单：**
      
      #{winner_list}
      
      恭喜以上用户中奖！请注意查收私信通知。
    TEXT
    
    PostCreator.create!(
      Discourse.system_user,
      topic_id: lottery_entry.topic_id,
      raw: announcement
    )
  end

  def announce_cancellation(reason)
    announcement = <<~TEXT
      ❌ **抽奖活动已取消** ❌
      
      **活动名称：** #{lottery_entry.title}
      **取消原因：** #{reason}
      **取消时间：** #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
      
      感谢大家的参与！
    TEXT
    
    PostCreator.create!(
      Discourse.system_user,
      topic_id: lottery_entry.topic_id,
      raw: announcement
    )
  end

  def send_winner_notifications(winners)
    winners.each do |winner|
      message = <<~TEXT
        🎉 恭喜您在抽奖活动中获奖！
        
        **活动名称：** #{lottery_entry.title}
        **奖品说明：** #{lottery_entry.prize_description}
        **您的楼层：** #{winner[:floor]}楼
        **开奖时间：** #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
        
        请尽快联系活动发起者 @#{lottery_entry.user.username} 领取奖品。
        
        [查看抽奖主题](#{Discourse.base_url}/t/#{lottery_entry.topic.slug}/#{lottery_entry.topic_id})
      TEXT
      
      PostCreator.create!(
        Discourse.system_user,
        target_usernames: winner[:user].username,
        archetype: Archetype.private_message,
        title: "🎉 抽奖中奖通知 - #{lottery_entry.title}",
        raw: message
      )
    end
  end

  def update_topic_tags(new_tag)
    topic = lottery_entry.topic
    
    # 移除旧的抽奖标签
    old_tags = %w[抽奖中 已开奖 已取消]
    topic.tags = topic.tags.reject { |tag| old_tags.include?(tag.name) }
    
    # 添加新标签
    tag = Tag.find_or_create_by(name: new_tag)
    topic.tags << tag unless topic.tags.include?(tag)
    
    topic.save!
  end

  def lock_topic
    topic = lottery_entry.topic
    topic.update!(closed: true)
  end

  def failure(message)
    Rails.logger.error "LotteryManager failure: #{message}"
    false
  end
end
