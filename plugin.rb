# frozen_string_literal: true

# name: discourse-lottery-v7
# about: 精准、公平、健壮的自动化抽奖系统，支持随机抽取和指定楼层两种模式
# version: 7.0.0
# authors: Your Name
# url: https://github.com/your-username/discourse-lottery-v7
# required_version: 3.1.0
# transpile_js: true

enabled_site_setting :lottery_enabled

register_asset "stylesheets/lottery.scss"

PLUGIN_NAME = "discourse-lottery-v7"

after_initialize do
  # 注册自定义字段类型 (沿用你原有的方式)
  register_topic_custom_field_type("lottery_title", :string)
  register_topic_custom_field_type("lottery_prize_description", :text)
  register_topic_custom_field_type("lottery_image_upload_id", :integer)
  register_topic_custom_field_type("lottery_draw_time", :string)
  register_topic_custom_field_type("lottery_winner_count", :integer)
  register_topic_custom_field_type("lottery_specified_floors", :string)
  register_topic_custom_field_type("lottery_min_participants", :integer)
  register_topic_custom_field_type("lottery_backup_strategy", :string)
  register_topic_custom_field_type("lottery_additional_notes", :text)
  register_topic_custom_field_type("lottery_type", :string)
  register_topic_custom_field_type("lottery_status", :string)
  register_topic_custom_field_type("lottery_winners_data", :json)

  # 确保自定义字段包含在序列化中 (沿用你原有的方式)
  TopicView.default_topic_custom_fields << "lottery_title"
  TopicView.default_topic_custom_fields << "lottery_prize_description"
  TopicView.default_topic_custom_fields << "lottery_image_upload_id"
  TopicView.default_topic_custom_fields << "lottery_draw_time"
  TopicView.default_topic_custom_fields << "lottery_winner_count"
  TopicView.default_topic_custom_fields << "lottery_specified_floors"
  TopicView.default_topic_custom_fields << "lottery_min_participants"
  TopicView.default_topic_custom_fields << "lottery_backup_strategy"
  TopicView.default_topic_custom_fields << "lottery_additional_notes"
  TopicView.default_topic_custom_fields << "lottery_type"
  TopicView.default_topic_custom_fields << "lottery_status"
  TopicView.default_topic_custom_fields << "lottery_winners_data"

  # 加载库文件 (基于你原有的加载方式)
  load File.expand_path('../lib/lottery_creator.rb', __FILE__)
  load File.expand_path('../lib/lottery_manager.rb', __FILE__)
  load File.expand_path('../lib/lottery_validator.rb', __FILE__)
  load File.expand_path('../app/controllers/lottery_controller.rb', __FILE__)

  # 加载任务
  load File.expand_path('../app/jobs/execute_lottery_draw.rb', __FILE__)
  load File.expand_path('../app/jobs/execute_lottery_creator.rb', __FILE__)
  load File.expand_path('../app/jobs/lock_lottery_post.rb', __FILE__)

  # 注册路由
  Discourse::Application.routes.append do
    post '/lottery/create' => 'lottery#create'
    get '/lottery/:topic_id' => 'lottery#show'
  end

  # 扩展 Topic 模型 (基于你原有的方式)
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
        status: custom_fields["lottery_status"] || "running",
        winners_data: custom_fields["lottery_winners_data"]
      }
    end

    def lottery_image_upload
      return nil unless custom_fields["lottery_image_upload_id"].present?
      Upload.find_by(id: custom_fields["lottery_image_upload_id"])
    end
  end

  # 添加到序列化器 (基于你原有的方式)
  add_to_serializer(:topic_view, :lottery_data, include_condition: -> { object.topic.has_lottery? }) do
    data = object.topic.lottery_data
    if data && data[:image_upload_id].present?
      upload = object.topic.lottery_image_upload
      data[:image_url] = upload&.url
    end
    data
  end

  # 监听主题创建事件
  DiscourseEvent.on(:topic_created) do |topic, opts, user|
    next unless SiteSetting.lottery_enabled
    next unless topic.custom_fields["lottery_title"].present?
    
    Jobs.enqueue(:execute_lottery_creator, {
      topic_id: topic.id,
      user_id: user.id
    })
  end

  # 监听帖子编辑事件
  DiscourseEvent.on(:post_edited) do |post, topic_changed, revisor|
    next unless SiteSetting.lottery_enabled
    next unless post.is_first_post?
    next unless post.topic.has_lottery?
    
    # 检查是否还在后悔期内
    begin
      lock_time = Time.parse(post.topic.custom_fields["lottery_draw_time"]) - SiteSetting.lottery_post_lock_delay_minutes.minutes
      next if Time.current > lock_time
    rescue
      next
    end
    
    # 重新验证和处理抽奖数据
    Jobs.enqueue(:execute_lottery_creator, {
      topic_id: post.topic_id,
      user_id: post.user_id,
      is_edit: true
    })
  end
end
