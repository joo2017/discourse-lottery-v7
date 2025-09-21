# frozen_string_literal: true

module Jobs
  class ExecuteLotteryCreator < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]
      user_id = args[:user_id]
      is_edit = args[:is_edit] || false
      
      topic = Topic.find_by(id: topic_id)
      user = User.find_by(id: user_id)
      
      unless topic && user
        Rails.logger.error "ExecuteLotteryCreator: Topic #{topic_id} or User #{user_id} not found"
        return
      end
      
      Rails.logger.info "ExecuteLotteryCreator: 处理抽奖#{is_edit ? '编辑' : '创建'} - Topic ##{topic.id}"
      
      if is_edit
        # 编辑模式：删除旧的调度任务和记录
        cleanup_existing_lottery(topic)
      end
      
      # 创建或更新抽奖
      creator = LotteryCreator.new(topic: topic, user: user)
      result = creator.create
      
      Rails.logger.info "ExecuteLotteryCreator: 结果 - #{result[:success] ? 'Success' : 'Failed'}: #{result[:message] || result[:error]}"
      
    rescue => e
      Rails.logger.error "ExecuteLotteryCreator error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # 发送错误通知
      if topic && user
        PostCreator.create!(
          Discourse.system_user,
          topic_id: topic.id,
          raw: "@#{user.username} 抽奖处理失败：系统错误。请联系管理员。"
        )
      end
    end

    private

    def cleanup_existing_lottery(topic)
      # 删除现有的数据库记录
      existing_entry = LotteryEntry.find_by(topic_id: topic.id)
      if existing_entry
        Rails.logger.info "删除现有抽奖记录 ##{existing_entry.id}"
        existing_entry.destroy
      end
      
      # 注意：Sidekiq jobs 一旦入队就无法轻易删除
      # 在 ExecuteLotteryDraw 中需要检查记录是否仍然存在
    end
  end
end
