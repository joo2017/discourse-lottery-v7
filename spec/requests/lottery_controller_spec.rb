# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LotteryController, type: :request do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  
  before do
    SiteSetting.lottery_enabled = true
    SiteSetting.lottery_min_participants_global = 5
    sign_in(user)
  end
  
  describe 'POST #create' do
    let(:valid_params) {
      {
        topic_id: topic.id,
        lottery_title: 'Test Lottery',
        lottery_prize_description: 'Test Prize',
        lottery_draw_time: 1.day.from_now.iso8601,
        lottery_winner_count: 3,
        lottery_min_participants: 5,
        lottery_backup_strategy: 'continue'
      }
    }
    
    context 'when lottery is disabled' do
      before { SiteSetting.lottery_enabled = false }
      
      it 'returns 404' do
        post '/lottery/create', params: valid_params
        expect(response).to have_http_status(:not_found)
      end
    end
    
    context 'when user is not logged in' do
      before { sign_out }
      
      it 'returns 403' do
        post '/lottery/create', params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end
    
    context 'when user cannot edit topic' do
      let(:other_user) { Fabricate(:user) }
      let(:other_topic) { Fabricate(:topic, user: other_user) }
      
      it 'returns 403' do
        post '/lottery/create', params: valid_params.merge(topic_id: other_topic.id)
        expect(response).to have_http_status(:forbidden)
      end
    end
    
    context 'with valid params' do
      it 'creates lottery successfully' do
        expect {
          post '/lottery/create', params: valid_params
        }.to change(LotteryEntry, :count).by(1)
        
        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['lottery_data']).to be_present
      end
    end
    
    context 'with invalid params' do
      let(:invalid_params) {
        valid_params.merge(lottery_min_participants: 2) # Below global minimum
      }
      
      it 'returns validation errors' do
        post '/lottery/create', params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['errors']).to be_present
      end
    end
  end
  
  describe 'GET #show' do
    let!(:lottery_entry) { 
      Fabricate(:lottery_entry, topic: topic, user: user) 
    }
    
    context 'when lottery exists' do
      it 'returns lottery data' do
        get "/lottery/#{topic.id}"
        
        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['lottery']['id']).to eq(lottery_entry.id)
      end
    end
    
    context 'when lottery does not exist' do
      let(:empty_topic) { Fabricate(:topic) }
      
      it 'returns 404' do
        get "/lottery/#{empty_topic.id}"
        
        expect(response).to have_http_status(:not_found)
        
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
    
    context 'when topic does not exist' do
      it 'returns 404' do
        get "/lottery/99999"
        
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
