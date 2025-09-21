# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::ExecuteLotteryDraw do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:lottery_entry) {
    Fabricate(:lottery_entry,
      topic: topic,
      user: user,
      status: 'running',
      min_participants: 2,
      winner_count: 1,
      lottery_type: 'random',
      backup_strategy: 'continue'
    )
  }
  
  let(:participant1) { Fabricate(:user) }
  let(:participant2) { Fabricate(:user) }
  
  before do
    SiteSetting.lottery_excluded_groups = 'staff'
  end
  
  describe '#execute' do
    context 'when lottery entry does not exist' do
      it 'logs error and returns' do
        expect(Rails.logger).to receive(:error).with(/not found/)
        
        described_class.new.execute(lottery_entry_id: 99999)
      end
    end
    
    context 'when lottery is no longer running' do
      before { lottery_entry.update!(status: 'finished') }
      
      it 'does not process the lottery' do
        expect(LotteryManager).not_to receive(:new)
        
        described_class.new.execute(lottery_entry_id: lottery_entry.id)
      end
    end
    
    context 'with sufficient participants' do
      before do
        Fabricate(:post, topic: topic, user: participant1)
        Fabricate(:post, topic: topic, user: participant2)
      end
      
      it 'executes the lottery' do
        manager = instance_double(LotteryManager)
        expect(LotteryManager).to receive(:new)
          .with(lottery_entry: lottery_entry)
          .and_return(manager)
        expect(manager).to receive(:execute_draw)
        
        described_class.new.execute(lottery_entry_id: lottery_entry.id)
      end
    end
    
    context 'when an error occurs' do
      before do
        allow(LotteryManager).to receive(:new).and_raise(StandardError.new("Test error"))
      end
      
      it 'handles the error gracefully' do
        expect(Rails.logger).to receive(:error).with(/Test error/)
        expect {
          described_class.new.execute(lottery_entry_id: lottery_entry.id)
        }.not_to raise_error
        
        lottery_entry.reload
        expect(lottery_entry.status).to eq('cancelled')
      end
      
      it 'posts error message' do
        expect(PostCreator).to receive(:create!).with(
          Discourse.system_user,
          hash_including(
            topic_id: lottery_entry.topic_id,
            raw: /系统错误/
          )
        )
        
        described_class.new.execute(lottery_entry_id: lottery_entry.id)
      end
    end
  end
end
