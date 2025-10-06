require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_api_key}" } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'GET /api/v1/users/by_discord_id/:discord_id' do
    let(:user) { create(:user, username: 'testuser', email: 'test@example.com') }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789', username: 'discord_user') }

    context 'with valid authentication' do
      before { discord_account }

      it 'returns the user by discord_id' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}", headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns correct JSON structure' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('user')
        expect(json_response['user']).to include(
          'id' => user.id,
          'username' => user.username,
          'email' => user.email,
          'subscription_tier' => user.subscription_tier,
          'discord_id' => discord_account.discord_id,
          'discord_username' => discord_account.username
        )
      end

      it 'returns user data with correct values' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}", headers: valid_headers

        json_response = JSON.parse(response.body)
        user_data = json_response['user']

        expect(user_data['username']).to eq('testuser')
        expect(user_data['email']).to eq('test@example.com')
        expect(user_data['discord_id']).to eq('123456789')
        expect(user_data['discord_username']).to eq('discord_user')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        get '/api/v1/users/by_discord_id/nonexistent', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get '/api/v1/users/by_discord_id/nonexistent', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users' do
    let(:valid_params) do
      {
        username: 'newuser',
        email: 'newuser@example.com',
        discord_id: '987654321'
      }
    end

    context 'with valid authentication and parameters' do
      it 'creates a new user' do
        expect {
          post '/api/v1/users', params: valid_params, headers: valid_headers
        }.to change(User, :count).by(1)
      end

      it 'creates a discord account for the user' do
        expect {
          post '/api/v1/users', params: valid_params, headers: valid_headers
        }.to change(DiscordAccount, :count).by(1)
      end

      it 'initializes loyalty points for the user' do
        expect {
          post '/api/v1/users', params: valid_params, headers: valid_headers
        }.to change(LoyaltyPoint, :count).by(1)
      end

      it 'returns created status' do
        post '/api/v1/users', params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'returns the created user data' do
        post '/api/v1/users', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('user')
        expect(json_response['user']).to include(
          'username' => 'newuser',
          'email' => 'newuser@example.com',
          'discord_id' => '987654321',
          'subscription_tier' => 'free'
        )
      end

      it 'sets subscription tier to free by default' do
        post '/api/v1/users', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['user']['subscription_tier']).to eq('free')
      end

      it 'generates a random password for the user' do
        post '/api/v1/users', params: valid_params, headers: valid_headers

        user = User.find_by(email: 'newuser@example.com')
        expect(user.encrypted_password).not_to be_nil
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable entity for duplicate email' do
        create(:user, email: 'duplicate@example.com')

        post '/api/v1/users', params: {
          username: 'testuser',
          email: 'duplicate@example.com',
          discord_id: '123456'
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message for validation failure' do
        post '/api/v1/users', params: {
          username: '',
          email: 'invalid',
          discord_id: '123456'
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end

      it 'does not create user with missing username' do
        expect {
          post '/api/v1/users', params: {
            email: 'test@example.com',
            discord_id: '123456'
          }, headers: valid_headers
        }.not_to change(User, :count)
      end

      it 'does not create user with missing email' do
        expect {
          post '/api/v1/users', params: {
            username: 'testuser',
            discord_id: '123456'
          }, headers: valid_headers
        }.not_to change(User, :count)
      end

      it 'does not create user with missing discord_id' do
        expect {
          post '/api/v1/users', params: {
            username: 'testuser',
            email: 'test@example.com'
          }, headers: valid_headers
        }.not_to change(User, :count)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/users', params: valid_params, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a user' do
        expect {
          post '/api/v1/users', params: valid_params, headers: invalid_headers
        }.not_to change(User, :count)
      end
    end
  end

  describe 'JSON response format' do
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }

    before { discord_account }

    it 'returns valid JSON' do
      get "/api/v1/users/by_discord_id/#{discord_account.discord_id}", headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      get "/api/v1/users/by_discord_id/#{discord_account.discord_id}", headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end
end
