# frozen_string_literal: true

class LotteryController < ApplicationController
  before_action :ensure_logged_in
  before_action :ensure_lottery_enabled
  before_action :find_topic, only: [:show]

  def create
    topic = Topic.find(params[:topic_id])
    
    # 权限检查
    guardian.ensure_can_edit!(topic)
    
    # 参数验证
    validator = LotteryValidator.new(
      params: lottery_params,
      user: current_user,
      topic: topic
    )
    
    unless validator.valid?
      return render json: {
        success: false,
        errors: validator.errors.full_messages
      }, status: 422
    end

    # 更新主题自定义字段
    update_topic_custom_fields(topic)
    
    # 创建抽奖
    result = LotteryCreator.new(topic: topic, user: current_user).create
    
    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        lottery_data: topic.reload.lottery_data
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: 422
    end
    
  rescue => e
    Rails.logger.error "LotteryController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    render json: {
      success: false,
      error: "服务器错误: #{e.message}"
    }, status: 500
  end

  def show
    lottery_entry = LotteryEntry.find_by(topic_id: @topic.id)
    
    if lottery_entry
      render json: {
        success: true,
        lottery: lottery_entry_json(lottery_entry)
      }
    else
      render json: {
        success: false,
        error: "抽奖不存在"
      }, status: 404
    end
  end

  private

  def ensure_lottery_enabled
    raise Discourse::NotFound unless SiteSetting.lottery_enabled
  end

  def find_topic
    @topic = Topic.find(params[:topic_id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "主题不存在" }, status: 404
  end

  def lottery_params
    params.permit(
      :lottery_title,
      :lottery_prize_description,
      :lottery_image_upload_id,
      :lottery_draw_time,
      :lottery_winner_count,
      :lottery_specified_floors,
      :lottery_min_participants,
      :lottery_backup_strategy,
      :lottery_additional_notes
    )
  end

  def update_topic_custom_fields(topic)
    lottery_params.each do |key, value|
      topic.custom_fields[key] = value if value.present?
    end
    topic.save_custom_fields
  end

  def lottery_entry_json(lottery_entry)
    {
      id: lottery_entry.id,
      title: lottery_entry.title,
      prize_description: lottery_entry.prize_description,
      image_url: lottery_entry.image_upload&.url,
      draw_time: lottery_entry.draw_time.iso8601,
      winner_count: lottery_entry.winner_count,
      specified_floors: lottery_entry.specified_floors,
      min_participants: lottery_entry.min_participants,
      backup_strategy: lottery_entry.backup_strategy,
      additional_notes: lottery_entry.additional_notes,
      lottery_type: lottery_entry.lottery_type,
      status: lottery_entry.status,
      winners_data: lottery_entry.winners_data,
      created_at: lottery_entry.created_at.iso8601,
      updated_at: lottery_entry.updated_at.iso8601
    }
  end
end
