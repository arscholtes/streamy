require 'rails_helper'

RSpec.describe Api::V1::LoyaltyPointsController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_api_key}" } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'GET /api/v1/users/:user_id/loyalty_points' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user, points: 100, level: 5, total_earned: 500, total_spent: 400) }

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/users/#{user.id}/loyalty_points", headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns loyalty points data' do
        get "/api/v1/users/#{user.id}/loyalty_points", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('loyalty_points')
        expect(json_response['loyalty_points']).to include(
          'points' => 100,
          'level' => 5,
          'total_earned' => 500,
          'total_spent' => 400
        )
      end

      it 'includes points_to_next_level' do
        get "/api/v1/users/#{user.id}/loyalty_points", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['loyalty_points']).to have_key('points_to_next_level')
      end

      context 'when user has no loyalty points' do
        let(:user_without_points) { create(:user) }

        it 'creates loyalty points automatically' do
          expect {
            get "/api/v1/users/#{user_without_points.id}/loyalty_points", headers: valid_headers
          }.to change(LoyaltyPoint, :count).by(1)
        end

        it 'returns newly created loyalty points' do
          get "/api/v1/users/#{user_without_points.id}/loyalty_points", headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('loyalty_points')
        end
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        get '/api/v1/users/99999/loyalty_points', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get '/api/v1/users/99999/loyalty_points', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/users/#{user.id}/loyalty_points", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users/:user_id/loyalty_points/add' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user, points: 100, total_earned: 100) }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          amount: 50,
          description: 'Test reward',
          transaction_type: 'earned_custom',
          metadata: { source: 'test' }
        }
      end

      it 'returns success status' do
        post "/api/v1/users/#{user.id}/loyalty_points/add", params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'adds points to user balance' do
        post "/api/v1/users/#{user.id}/loyalty_points/add", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['loyalty_points']['points']).to eq(150)
      end

      it 'updates total_earned' do
        post "/api/v1/users/#{user.id}/loyalty_points/add", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['loyalty_points']['total_earned']).to eq(150)
      end

      it 'returns updated loyalty points data' do
        post "/api/v1/users/#{user.id}/loyalty_points/add", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('loyalty_points')
        expect(json_response['loyalty_points']).to have_key('points')
        expect(json_response['loyalty_points']).to have_key('level')
      end

      context 'when user has no loyalty points' do
        let(:user_without_points) { create(:user) }

        it 'creates loyalty points and adds amount' do
          post "/api/v1/users/#{user_without_points.id}/loyalty_points/add",
               params: { amount: 25 }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['loyalty_points']['points']).to be >= 25
        end
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid amount' do
        post "/api/v1/users/#{user.id}/loyalty_points/add",
             params: { amount: -10 }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        post '/api/v1/users/99999/loyalty_points/add',
             params: { amount: 50 }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post "/api/v1/users/#{user.id}/loyalty_points/add",
             params: { amount: 50 }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users/:user_id/loyalty_points/spend' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user, points: 100, total_spent: 50) }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          amount: 30,
          description: 'Test purchase',
          transaction_type: 'spent_custom',
          metadata: { item: 'test_item' }
        }
      end

      it 'returns success status' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend", params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'deducts points from user balance' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['loyalty_points']['points']).to eq(70)
      end

      it 'updates total_spent' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['loyalty_points']['total_spent']).to eq(80)
      end

      it 'returns updated loyalty points data' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('loyalty_points')
        expect(json_response['loyalty_points']).to have_key('points')
        expect(json_response['loyalty_points']).to have_key('level')
      end
    end

    context 'with insufficient points' do
      it 'returns error message' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend",
             params: { amount: 200 }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Insufficient points or invalid amount')
      end
    end

    context 'with invalid amount' do
      it 'returns error for negative amount' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend",
             params: { amount: -10 }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user has no loyalty points' do
      let(:user_without_points) { create(:user) }

      it 'returns not found status' do
        post "/api/v1/users/#{user_without_points.id}/loyalty_points/spend",
             params: { amount: 10 }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post "/api/v1/users/#{user_without_points.id}/loyalty_points/spend",
             params: { amount: 10 }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User has no loyalty points')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        post '/api/v1/users/99999/loyalty_points/spend',
             params: { amount: 10 }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post "/api/v1/users/#{user.id}/loyalty_points/spend",
             params: { amount: 10 }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/loyalty_points/leaderboard' do
    let!(:user1) { create(:user, username: 'user1') }
    let!(:user2) { create(:user, username: 'user2') }
    let!(:user3) { create(:user, username: 'user3') }
    let!(:lp1) { create(:loyalty_point, user: user1, points: 500, total_earned: 1000) }
    let!(:lp2) { create(:loyalty_point, user: user2, points: 300, total_earned: 800) }
    let!(:lp3) { create(:loyalty_point, user: user3, points: 100, total_earned: 600) }

    context 'with valid authentication' do
      it 'returns success status' do
        get '/api/v1/loyalty_points/leaderboard', headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns leaderboard data ordered by total_earned' do
        get '/api/v1/loyalty_points/leaderboard', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('leaderboard')
        expect(json_response['leaderboard'].length).to eq(3)
        expect(json_response['leaderboard'][0]['username']).to eq('user1')
        expect(json_response['leaderboard'][1]['username']).to eq('user2')
        expect(json_response['leaderboard'][2]['username']).to eq('user3')
      end

      it 'includes rank for each entry' do
        get '/api/v1/loyalty_points/leaderboard', headers: valid_headers

        json_response = JSON.parse(response.body)
        leaderboard = json_response['leaderboard']
        expect(leaderboard[0]['rank']).to eq(1)
        expect(leaderboard[1]['rank']).to eq(2)
        expect(leaderboard[2]['rank']).to eq(3)
      end

      it 'includes all required fields for each entry' do
        get '/api/v1/loyalty_points/leaderboard', headers: valid_headers

        json_response = JSON.parse(response.body)
        entry = json_response['leaderboard'].first
        expect(entry).to include(
          'rank',
          'user_id',
          'username',
          'points',
          'level',
          'total_earned'
        )
      end

      context 'with custom limit' do
        it 'returns specified number of entries' do
          get '/api/v1/loyalty_points/leaderboard', params: { limit: 2 }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['leaderboard'].length).to eq(2)
        end
      end

      context 'without limit parameter' do
        it 'returns default 10 entries' do
          get '/api/v1/loyalty_points/leaderboard', headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['leaderboard'].length).to be <= 10
        end
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/v1/loyalty_points/leaderboard', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'JSON response format' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user) }

    it 'returns valid JSON' do
      get "/api/v1/users/#{user.id}/loyalty_points", headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      get "/api/v1/users/#{user.id}/loyalty_points", headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end
end
