# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LotteryCreator do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:creator) { LotteryCreator.new(topic: topic, user: user) }
  
  before do
    SiteSetting.lottery_enabled = true
    SiteSetting.lottery_min_participants_global = 5
  end
  
  describe '#create' do
    context 'when lottery is disabled' do
      before { SiteSetting.lottery_enabled = false }
      
      it 'returns failure' do
        result = creator.create
        expect(result[:success]).to be false
        expect(result[:error]).to include('抽奖功能未启用')
      end
    end
    
    context 'when required fields are missing' do
      it 'returns failure' do
        result = creator.create
        expect(result[:success]).to be false
        expect(result[:error]).to include('缺少必要的抽奖信息')
      end
    end
    
    context 'when min participants is below global minimum' do
      before do
        topic.custom_fields.merge!(
          'lottery_title' => 'Test Lottery',
          'lottery_prize_description' => 'Test Prize',
          'lottery_draw_time' => 1.day.from_now.iso8601,
          'lottery_winner_count' => '1',
          'lottery_min_participants' => '3', # Below global minimum of 5
          'lottery_backup_strategy' => 'continue'
        )
        topic.save_custom_fields
      end
      
      it 'returns failure' do
        result = creator.create
        expect(result[:success]).to be false
        expect(result[:error]).to include('参与门槛不能低于')
      end
    end
    
    context 'when draw time is in the past' do
      before do
        topic.custom_fields.merge!(
          'lottery_title' => 'Test Lottery',
          'lottery_prize_description' => 'Test Prize',
          'lottery_draw_time' => 1.hour.ago.iso8601,
          'lottery_winner_count' => '1',
          'lottery_min_participants' => '5',
          'lottery_backup_strategy' => 'continue'
        )
        topic.save_custom_fields
      end
      
      it 'returns failure' do
        result = creator.create
        expect(result[:success]).to be false
        expect(result[:error]).to include('开奖时间必须是未来时间')
      end
    end
    
    context 'with valid random lottery data' do
      before do
        topic.custom_fields.merge!(
          'lottery_title' => 'Test Lottery',
          'lottery_prize_description' => 'Test Prize',
          'lottery_draw_time' => 1.day.from_now.iso8601,
          'lottery_winner_count' => '3',
          'lottery_min_participants' => '5',
          'lottery_backup_strategy' => 'continue'
        )
        topic.save_custom_fields
      end
      
      it 'creates lottery successfully' do
        expect {
          result = creator.create
          expect(result[:success]).to be true
        }.to change(LotteryEntry, :count).by(1)
        
        lottery = LotteryEntry.last
        expect(lottery.title).to eq('Test Lottery')
        expect(lottery.lottery_type).to eq('random')
        expect(lottery.winner_count).to eq(3)
      end
      
      it 'schedules jobs' do
        expect(Jobs).to receive(:enqueue_at).twice # draw and lock jobs
        creator.create
      end
      
      it 'adds lottery tag' do
        creator.create
        topic.reload
        expect(topic.tags.pluck(:name)).to include('抽奖中')
      end
    end
    
    context 'with specified floors' do
      before do
        topic.custom_fields.merge!(
          'lottery_title' => 'Test Lottery',
          'lottery_prize_description' => 'Test Prize',
          'lottery_draw_time' => 1.day.from_now.iso8601,
          'lottery_winner_count' => '3',
          'lottery_specified_floors' => '5, 10, 15',
          'lottery_min_participants' => '5',
          'lottery_backup_strategy' => 'continue'
        )
        topic.save_custom_fields
      end
      
      it 'creates specified floor lottery' do
        result = creator.create
        expect(result[:success]).to be true
        
        lottery = LotteryEntry.last
        expect(lottery.lottery_type).to eq('specified')
        expect(lottery.winner_count).to eq(3) # 3 floors specified
        expect(lottery.specified_floors).to eq('5,10,15')
      end
    end
  end
end
