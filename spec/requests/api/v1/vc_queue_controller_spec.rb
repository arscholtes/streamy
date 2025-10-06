require 'rails_helper'

RSpec.describe Api::V1::VcQueueController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_api_key}" } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'GET /api/v1/vc_queue' do
    let(:user1) { create(:user, username: 'user1') }
    let(:user2) { create(:user, username: 'user2') }
    let(:user3) { create(:user, username: 'user3') }
    let!(:queue1) { create(:vc_queue_entry, user: user1, discord_user_id: '111', priority: 10, position: 1, status: 'waiting') }
    let!(:queue2) { create(:vc_queue_entry, user: user2, discord_user_id: '222', priority: 5, position: 2, status: 'waiting') }
    let!(:queue3) { create(:vc_queue_entry, user: user3, discord_user_id: '333', priority: 1, position: 3, status: 'cancelled') }

    context 'with valid authentication' do
      it 'returns success status' do
        get '/api/v1/vc_queue', headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns only waiting queue entries' do
        get '/api/v1/vc_queue', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('queue')
        expect(json_response['queue'].length).to eq(2)
      end

      it 'returns queue entries ordered by priority' do
        get '/api/v1/vc_queue', headers: valid_headers

        json_response = JSON.parse(response.body)
        queue = json_response['queue']
        expect(queue.first['priority']).to be >= queue.last['priority']
      end

      it 'returns queue entries with correct structure' do
        get '/api/v1/vc_queue', headers: valid_headers

        json_response = JSON.parse(response.body)
        entry = json_response['queue'].first
        expect(entry).to include(
          'id',
          'user_id',
          'username',
          'discord_user_id',
          'priority',
          'position',
          'wait_time',
          'joined_at'
        )
      end

      it 'includes user information' do
        get '/api/v1/vc_queue', headers: valid_headers

        json_response = JSON.parse(response.body)
        entry = json_response['queue'].first
        expect(entry['username']).to eq(user1.username)
      end
    end

    context 'when queue is empty' do
      before do
        VcQueueEntry.destroy_all
      end

      it 'returns empty array' do
        get '/api/v1/vc_queue', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['queue']).to eq([])
      end

      it 'still returns success status' do
        get '/api/v1/vc_queue', headers: valid_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/v1/vc_queue', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/vc_queue/join' do
    let(:user) { create(:user) }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          user_id: user.id,
          discord_user_id: '123456789',
          priority: 5
        }
      end

      it 'returns created status' do
        post '/api/v1/vc_queue/join', params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'creates a new queue entry' do
        expect {
          post '/api/v1/vc_queue/join', params: valid_params, headers: valid_headers
        }.to change(VcQueueEntry, :count).by(1)
      end

      it 'returns the created queue entry' do
        post '/api/v1/vc_queue/join', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('queue_entry')
        expect(json_response['queue_entry']).to include(
          'id',
          'position',
          'priority',
          'joined_at'
        )
      end

      it 'sets the correct position in queue' do
        create(:vc_queue_entry, user: create(:user), position: 1, status: 'waiting')
        create(:vc_queue_entry, user: create(:user), position: 2, status: 'waiting')

        post '/api/v1/vc_queue/join', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['queue_entry']['position']).to eq(3)
      end

      it 'sets status to waiting' do
        post '/api/v1/vc_queue/join', params: valid_params, headers: valid_headers

        entry = VcQueueEntry.last
        expect(entry.status).to eq('waiting')
      end

      context 'without priority parameter' do
        it 'calculates priority automatically' do
          post '/api/v1/vc_queue/join', params: {
            user_id: user.id,
            discord_user_id: '123456789'
          }, headers: valid_headers

          expect(response).to have_http_status(:created)
          json_response = JSON.parse(response.body)
          expect(json_response['queue_entry']).to have_key('priority')
        end
      end
    end

    context 'when user already in queue' do
      before do
        create(:vc_queue_entry, user: user, status: 'waiting')
      end

      it 'returns error message' do
        post '/api/v1/vc_queue/join', params: {
          user_id: user.id,
          discord_user_id: '123456789'
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Already in queue')
      end

      it 'does not create duplicate entry' do
        expect {
          post '/api/v1/vc_queue/join', params: {
            user_id: user.id,
            discord_user_id: '123456789'
          }, headers: valid_headers
        }.not_to change(VcQueueEntry, :count)
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        post '/api/v1/vc_queue/join', params: {
          user_id: 99999,
          discord_user_id: '123456789'
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post '/api/v1/vc_queue/join', params: {
          user_id: 99999,
          discord_user_id: '123456789'
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/vc_queue/join', params: {
          user_id: user.id,
          discord_user_id: '123456789'
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create queue entry' do
        expect {
          post '/api/v1/vc_queue/join', params: {
            user_id: user.id,
            discord_user_id: '123456789'
          }, headers: invalid_headers
        }.not_to change(VcQueueEntry, :count)
      end
    end
  end

  describe 'DELETE /api/v1/vc_queue/leave' do
    let(:user) { create(:user) }
    let!(:queue_entry) { create(:vc_queue_entry, user: user, status: 'waiting') }

    context 'with valid authentication' do
      it 'returns success status' do
        delete '/api/v1/vc_queue/leave', params: { user_id: user.id }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'marks entry as cancelled' do
        delete '/api/v1/vc_queue/leave', params: { user_id: user.id }, headers: valid_headers

        queue_entry.reload
        expect(queue_entry.status).to eq('cancelled')
      end

      it 'returns success message' do
        delete '/api/v1/vc_queue/leave', params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Left queue successfully')
      end

      it 'does not delete the entry from database' do
        expect {
          delete '/api/v1/vc_queue/leave', params: { user_id: user.id }, headers: valid_headers
        }.not_to change(VcQueueEntry, :count)
      end
    end

    context 'when user is not in queue' do
      let(:user_not_in_queue) { create(:user) }

      it 'returns not found status' do
        delete '/api/v1/vc_queue/leave', params: { user_id: user_not_in_queue.id }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        delete '/api/v1/vc_queue/leave', params: { user_id: user_not_in_queue.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not in queue')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        delete '/api/v1/vc_queue/leave', params: { user_id: 99999 }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        delete '/api/v1/vc_queue/leave', params: { user_id: 99999 }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        delete '/api/v1/vc_queue/leave', params: { user_id: user.id }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/vc_queue/next' do
    let(:user1) { create(:user, username: 'high_priority') }
    let(:user2) { create(:user, username: 'low_priority') }
    let!(:queue1) { create(:vc_queue_entry, user: user1, discord_user_id: '111', priority: 10, status: 'waiting') }
    let!(:queue2) { create(:vc_queue_entry, user: user2, discord_user_id: '222', priority: 5, status: 'waiting') }

    context 'with valid authentication' do
      it 'returns success status' do
        post '/api/v1/vc_queue/next', headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns the highest priority user' do
        post '/api/v1/vc_queue/next', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('user')
        expect(json_response['user']['username']).to eq('high_priority')
      end

      it 'marks the entry as active' do
        post '/api/v1/vc_queue/next', headers: valid_headers

        queue1.reload
        expect(queue1.status).to eq('active')
      end

      it 'returns user information' do
        post '/api/v1/vc_queue/next', headers: valid_headers

        json_response = JSON.parse(response.body)
        user_data = json_response['user']
        expect(user_data).to include(
          'id',
          'username',
          'discord_user_id'
        )
      end
    end

    context 'when queue is empty' do
      before do
        VcQueueEntry.destroy_all
      end

      it 'returns not found status' do
        post '/api/v1/vc_queue/next', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post '/api/v1/vc_queue/next', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Queue is empty')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/vc_queue/next', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'JSON response format' do
    let(:user) { create(:user) }
    let!(:queue_entry) { create(:vc_queue_entry, user: user, status: 'waiting') }

    it 'returns valid JSON' do
      get '/api/v1/vc_queue', headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      get '/api/v1/vc_queue', headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end
end
