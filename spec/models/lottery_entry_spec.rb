# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LotteryEntry, type: :model do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  
  describe 'validations' do
    it 'requires title' do
      lottery = LotteryEntry.new
      expect(lottery).not_to be_valid
      expect(lottery.errors[:title]).to be_present
    end
    
    it 'requires prize_description' do
      lottery = LotteryEntry.new(title: 'Test')
      expect(lottery).not_to be_valid
      expect(lottery.errors[:prize_description]).to be_present
    end
    
    it 'requires future draw_time' do
      lottery = LotteryEntry.new(
        title: 'Test',
        prize_description: 'Prize',
        draw_time: 1.hour.ago
      )
      expect(lottery).not_to be_valid
    end
    
    it 'validates winner_count range' do
      lottery = LotteryEntry.new(winner_count: 0)
      expect(lottery).not_to be_valid
      
      lottery.winner_count = 101
      expect(lottery).not_to be_valid
      
      lottery.winner_count = 5
      expect(lottery).to be_valid
    end
    
    it 'validates backup_strategy inclusion' do
      lottery = LotteryEntry.new(backup_strategy: 'invalid')
      expect(lottery).not_to be_valid
      
      lottery.backup_strategy = 'continue'
      expect(lottery).to be_valid
      
      lottery.backup_strategy = 'cancel'
      expect(lottery).to be_valid
    end
  end
  
  describe 'associations' do
    it 'belongs to topic' do
      expect(LotteryEntry.reflect_on_association(:topic).macro).to eq(:belongs_to)
    end
    
    it 'belongs to user' do
      expect(LotteryEntry.reflect_on_association(:user).macro).to eq(:belongs_to)
    end
  end
  
  describe 'scopes' do
    let!(:running_lottery) { Fabricate(:lottery_entry, status: 'running') }
    let!(:finished_lottery) { Fabricate(:lottery_entry, status: 'finished') }
    let!(:cancelled_lottery) { Fabricate(:lottery_entry, status: 'cancelled') }
    
    it 'filters by status' do
      expect(LotteryEntry.running).to include(running_lottery)
      expect(LotteryEntry.running).not_to include(finished_lottery)
      
      expect(LotteryEntry.finished).to include(finished_lottery)
      expect(LotteryEntry.finished).not_to include(running_lottery)
      
      expect(LotteryEntry.cancelled).to include(cancelled_lottery)
      expect(LotteryEntry.cancelled).not_to include(running_lottery)
    end
    
    it 'finds due lotteries' do
      past_lottery = Fabricate(:lottery_entry, 
        status: 'running', 
        draw_time: 1.hour.ago
      )
      future_lottery = Fabricate(:lottery_entry, 
        status: 'running', 
        draw_time: 1.hour.from_now
      )
      
      expect(LotteryEntry.due_for_draw).to include(past_lottery)
      expect(LotteryEntry.due_for_draw).not_to include(future_lottery)
    end
  end
  
  describe '#specified_floors_array' do
    it 'parses specified_floors string' do
      lottery = LotteryEntry.new(specified_floors: '5, 10, 15')
      expect(lottery.specified_floors_array).to eq([5, 10, 15])
    end
    
    it 'returns empty array for nil' do
      lottery = LotteryEntry.new(specified_floors: nil)
      expect(lottery.specified_floors_array).to eq([])
    end
  end
  
  describe '#can_edit?' do
    it 'returns false for non-running lottery' do
      lottery = LotteryEntry.new(status: 'finished')
      expect(lottery.can_edit?).to be false
    end
    
    it 'checks time constraints for running lottery' do
      future_time = 2.hours.from_now
      lottery = LotteryEntry.new(
        status: 'running',
        draw_time: future_time
      )
      
      allow(SiteSetting).to
