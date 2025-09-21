# frozen_string_literal: true

module Jobs
  class ExecuteLotteryDraw < ::Jobs::Base
    def execute(args)
      lottery_entry_id = args[:lottery_entry_id]
      
      lottery_entry = LotteryEntry.find_by(id: lottery_entry_id)
      unless lottery_entry
        Rails.logger.error "ExecuteLotteryDraw: LotteryEntry #{lottery_entry_id} not found"
        return
      end
      
      Rails.logger.info "ExecuteLotteryDraw: 开始执行抽奖 ##{lottery_entry.id}"
      
      manager = LotteryManager.new(lottery_entry: lottery_entry)
      manager.execute_draw
      
    rescue => e
      Rails.logger.error "ExecuteLotteryDraw error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # 尝试标记抽奖为失败状态
      if lottery_entry
        lottery_entry.update(status: 'cancelled')
        
        # 发送错误通知
        PostCreator.create!(
          Discourse.system_user,
          topic_id: lottery_entry.topic_id,
          raw: "抽奖系统错误，活动已自动取消。错误信息：#{e.message}"
        )
      end
    end
  end
end
