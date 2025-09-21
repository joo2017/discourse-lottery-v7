# frozen_string_literal: true

# name: discourse-lottery-v7
# about: 精准、公平、健壮的自动化抽奖系统
# version: 7.0.0
# authors: Your Name
# url: https://github.com/your-username/discourse-lottery-v7
# required_version: 3.1.0
# transpile_js: true

enabled_site_setting :lottery_enabled

register_asset "stylesheets/lottery.scss"

after_initialize do
  # 注册自定义字段类型
  %w[
    lottery_title lottery_prize_description lottery_image_upload_id
    lottery_draw_time lottery_winner_count lottery_specified_floors
    lottery_min_participants lottery_backup_strategy lottery_additional_notes
    lottery_type lottery_status
  ].each do |field|
    register_topic_custom_field_type(field, :string)
  end

  # 加载文件
  [
    'app/models/lottery_entry',
    'lib/lottery_creator',
    'lib/lottery_manager', 
    'lib/lottery_validator',
    'app/controllers/lottery_controller',
    'app/jobs/execute_lottery_draw',
    'app/jobs/execute_lottery_creator',
    'app/jobs/lock_lottery_post'
  ].each { |file| load File.expand_path("../#{file}.rb", __FILE__) }

  # 注册路由
  Discourse::Application.routes.append do
    post '/lottery/create' => 'lottery#create'
    get '/lottery/:topic_id' => 'lottery#show'
  end

  # 扩展 Topic 模型
  Topic.class_eval do
    def has_lottery?
      custom_fields["lottery_title"].present?
    end

    def lottery_data
      return nil unless has_lottery?
      {
        title: custom_fields["lottery_title"],
        prize_description: custom_fields["lottery_prize_description"],
        image_upload_id: custom_fields["lottery_image_upload_id"],
        draw_time: custom_fields["lottery_draw_time"],
        winner_count: custom_fields["lottery_winner_count"],
        specified_floors: custom_fields["lottery_specified_floors"],
        min_participants: custom_fields["lottery_min_participants"],
        backup_strategy: custom_fields["lottery_backup_strategy"],
        additional_notes: custom_fields["lottery_additional_notes"],
        lottery_type: custom_fields["lottery_type"],
        status: custom_fields["lottery_status"] || "running"
      }
    end
  end

  # 序列化器
  add_to_serializer(:topic_view, :lottery_data, include_condition: -> { object.topic.has_lottery? }) do
    object.topic.lottery_data
  end

  # 事件监听
  DiscourseEvent.on(:topic_created) do |topic, opts, user|
    next unless SiteSetting.lottery_enabled
    next unless topic.custom_fields["lottery_title"].present?
    Jobs.enqueue(:execute_lottery_creator, topic_id: topic.id, user_id: user.id)
  end
end
