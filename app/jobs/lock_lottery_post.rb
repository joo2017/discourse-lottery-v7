# frozen_string_literal: true

module Jobs
  class LockLotteryPost < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]
      
      topic = Topic.find_by(id: topic_id)
      unless topic
        Rails.logger.error "LockLotteryPost: Topic #{topic_id} not found"
        return
      end
      
      # 检查抽奖是否仍在进行中
      lottery_entry = LotteryEntry.find_by(topic_id: topic_id, status: 'running')
      unless lottery_entry
        Rails.logger.info "LockLotteryPost: 抽奖已结束或不存在，跳过锁定"
        return
      end
      
      # 锁定主楼层
      first_post = topic.first_post
      if first_post && !first_post.locked?
        first_post.update!(locked: true)
        Rails.logger.info "LockLotteryPost: 已锁定主题 ##{topic_id} 的主楼层"
        
        # 发送锁定通知
        PostCreator.create!(
          Discourse.system_user,
          topic_id: topic_id,
          raw: "⏰ 抽奖规则保护期已结束，主楼层已锁定，无法再修改抽奖设置。"
        )
      end
      
    rescue => e
      Rails.logger.error "LockLotteryPost error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
