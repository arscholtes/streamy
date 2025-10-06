
require 'rails_helper'

RSpec.describe Api::V1::AchievementsController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_api_key}" } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'GET /api/v1/achievements' do
    let!(:achievement1) { create(:achievement, name: 'First Steps', category: 'beginner', points_reward: 10) }
    let!(:achievement2) { create(:achievement, name: 'Expert', category: 'advanced', points_reward: 50) }
    let!(:achievement3) { create(:achievement, name: 'Master', category: 'advanced', points_reward: 100) }

    context 'with valid authentication' do
      it 'returns success status' do
        get '/api/v1/achievements', headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns all achievements' do
        get '/api/v1/achievements', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('achievements')
        expect(json_response['achievements'].length).to eq(3)
      end

      it 'returns achievements with correct structure' do
        get '/api/v1/achievements', headers: valid_headers

        json_response = JSON.parse(response.body)
        achievement = json_response['achievements'].first
        expect(achievement).to include(
          'id',
          'name',
          'description',
          'category',
          'points_reward',
          'icon'
        )
      end

      it 'returns achievements in ordered format' do
        get '/api/v1/achievements', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['achievements']).to be_an(Array)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/v1/achievements', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/achievements/user/:user_id' do
    let(:user) { create(:user) }
    let!(:achievement1) { create(:achievement, name: 'Achievement 1', points_reward: 10) }
    let!(:achievement2) { create(:achievement, name: 'Achievement 2', points_reward: 20) }
    let!(:user_achievement1) { create(:user_achievement, user: user, achievement: achievement1, earned_at: 2.days.ago) }

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/achievements/user/#{user.id}", headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns only earned achievements for the user' do
        get "/api/v1/achievements/user/#{user.id}", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('achievements')
        expect(json_response['achievements'].length).to eq(1)
      end

      it 'returns achievement with earned_at timestamp' do
        get "/api/v1/achievements/user/#{user.id}", headers: valid_headers

        json_response = JSON.parse(response.body)
        achievement = json_response['achievements'].first
        expect(achievement).to include(
          'id',
          'name',
          'description',
          'category',
          'points_reward',
          'earned_at',
          'icon'
        )
      end

      it 'includes correct achievement data' do
        get "/api/v1/achievements/user/#{user.id}", headers: valid_headers

        json_response = JSON.parse(response.body)
        achievement = json_response['achievements'].first
        expect(achievement['name']).to eq('Achievement 1')
        expect(achievement['points_reward']).to eq(10)
      end

      context 'when user has no achievements' do
        let(:user_without_achievements) { create(:user) }

        it 'returns empty array' do
          get "/api/v1/achievements/user/#{user_without_achievements.id}", headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['achievements']).to eq([])
        end

        it 'still returns success status' do
          get "/api/v1/achievements/user/#{user_without_achievements.id}", headers: valid_headers

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        get '/api/v1/achievements/user/99999', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get '/api/v1/achievements/user/99999', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/achievements/user/#{user.id}", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/achievements/award' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user, points: 0, total_earned: 0) }
    let(:achievement) { create(:achievement, points_reward: 50) }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          user_id: user.id,
          achievement_id: achievement.id
        }
      end

      it 'returns created status' do
        post '/api/v1/achievements/award', params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'creates a user achievement record' do
        expect {
          post '/api/v1/achievements/award', params: valid_params, headers: valid_headers
        }.to change(UserAchievement, :count).by(1)
      end

      it 'returns the awarded achievement data' do
        post '/api/v1/achievements/award', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('achievement')
        expect(json_response['achievement']).to include(
          'id' => achievement.id,
          'name' => achievement.name,
          'points_reward' => achievement.points_reward
        )
      end

      it 'includes earned_at timestamp in response' do
        post '/api/v1/achievements/award', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['achievement']).to have_key('earned_at')
        expect(json_response['achievement']['earned_at']).not_to be_nil
      end

      it 'awards points to the user' do
        expect {
          post '/api/v1/achievements/award', params: valid_params, headers: valid_headers
          loyalty_points.reload
        }.to change { loyalty_points.points }.by(achievement.points_reward)
      end
    end

    context 'when achievement already earned' do
      before do
        create(:user_achievement, user: user, achievement: achievement)
      end

      it 'returns error message' do
        post '/api/v1/achievements/award', params: {
          user_id: user.id,
          achievement_id: achievement.id
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Achievement already earned or error occurred')
      end

      it 'does not create duplicate user achievement' do
        expect {
          post '/api/v1/achievements/award', params: {
            user_id: user.id,
            achievement_id: achievement.id
          }, headers: valid_headers
        }.not_to change(UserAchievement, :count)
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        post '/api/v1/achievements/award', params: {
          user_id: 99999,
          achievement_id: achievement.id
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post '/api/v1/achievements/award', params: {
          user_id: 99999,
          achievement_id: achievement.id
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'when achievement does not exist' do
      it 'returns not found status' do
        post '/api/v1/achievements/award', params: {
          user_id: user.id,
          achievement_id: 99999
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post '/api/v1/achievements/award', params: {
          user_id: user.id,
          achievement_id: 99999
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Achievement not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/achievements/award', params: {
          user_id: user.id,
          achievement_id: achievement.id
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not award achievement' do
        expect {
          post '/api/v1/achievements/award', params: {
            user_id: user.id,
            achievement_id: achievement.id
          }, headers: invalid_headers
        }.not_to change(UserAchievement, :count)
      end
    end
  end

  describe 'JSON response format' do
    let!(:achievement) { create(:achievement) }

    it 'returns valid JSON' do
      get '/api/v1/achievements', headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      get '/api/v1/achievements', headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end
end
