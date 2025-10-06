require 'rails_helper'

RSpec.describe Api::V1::ObsConnectionsController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'X-API-Key' => valid_api_key } }
  let(:invalid_headers) { { 'X-API-Key' => 'invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'GET /api/v1/users/:user_id/obs_connection' do
    let(:user) { create(:user) }
    let!(:obs_connection) do
      create(:obs_connection,
        user: user,
        host: 'localhost',
        port: 4455,
        version: '5.0.0',
        connected: true,
        last_connected_at: 1.hour.ago
      )
    end

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns OBS connection data' do
        get "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('obs_connection')
        expect(json_response['obs_connection']).to include(
          'id',
          'host',
          'port',
          'version',
          'connected',
          'last_connected_at',
          'created_at',
          'updated_at'
        )
      end

      it 'returns correct connection values' do
        get "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

        json_response = JSON.parse(response.body)
        connection = json_response['obs_connection']
        expect(connection['host']).to eq('localhost')
        expect(connection['port']).to eq(4455)
        expect(connection['version']).to eq('5.0.0')
        expect(connection['connected']).to be true
      end
    end

    context 'when user has no OBS connection' do
      let(:user_without_obs) { create(:user) }

      it 'returns not found status' do
        get "/api/v1/users/#{user_without_obs.id}/obs_connection", headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get "/api/v1/users/#{user_without_obs.id}/obs_connection", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OBS connection not found')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        get '/api/v1/users/99999/obs_connection', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get '/api/v1/users/99999/obs_connection', headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/users/#{user.id}/obs_connection", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users/:user_id/obs_connection' do
    let(:user) { create(:user) }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          host: 'localhost',
          port: 4455,
          password_encrypted: 'encrypted_password',
          version: '5.0.0',
          connected: true,
          connection_name: 'Main OBS'
        }
      end

      it 'returns created status' do
        post "/api/v1/users/#{user.id}/obs_connection", params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'creates a new OBS connection' do
        expect {
          post "/api/v1/users/#{user.id}/obs_connection", params: valid_params, headers: valid_headers
        }.to change(ObsConnection, :count).by(1)
      end

      it 'returns the created connection data' do
        post "/api/v1/users/#{user.id}/obs_connection", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('obs_connection')
        expect(json_response['obs_connection']).to include(
          'id',
          'host',
          'port',
          'version',
          'connected',
          'last_connected_at'
        )
      end

      it 'returns success message' do
        post "/api/v1/users/#{user.id}/obs_connection", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('OBS connection saved successfully')
      end

      it 'sets last_connected_at when connected is true' do
        post "/api/v1/users/#{user.id}/obs_connection", params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['obs_connection']['last_connected_at']).not_to be_nil
      end

      context 'when updating existing connection' do
        let!(:existing_connection) do
          create(:obs_connection, user: user, host: 'old_host', port: 4444)
        end

        it 'updates the existing connection' do
          expect {
            post "/api/v1/users/#{user.id}/obs_connection", params: valid_params, headers: valid_headers
          }.not_to change(ObsConnection, :count)

          existing_connection.reload
          expect(existing_connection.host).to eq('localhost')
          expect(existing_connection.port).to eq(4455)
        end
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable entity status' do
        post "/api/v1/users/#{user.id}/obs_connection", params: {
          host: '',
          port: -1
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error details' do
        post "/api/v1/users/#{user.id}/obs_connection", params: {
          host: '',
          port: -1
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to save OBS connection')
        expect(json_response).to have_key('details')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        post '/api/v1/users/99999/obs_connection', params: {
          host: 'localhost',
          port: 4455
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post "/api/v1/users/#{user.id}/obs_connection", params: {
          host: 'localhost',
          port: 4455
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create connection' do
        expect {
          post "/api/v1/users/#{user.id}/obs_connection", params: {
            host: 'localhost',
            port: 4455
          }, headers: invalid_headers
        }.not_to change(ObsConnection, :count)
      end
    end
  end

  describe 'PATCH /api/v1/users/:user_id/obs_connection' do
    let(:user) { create(:user) }
    let!(:obs_connection) do
      create(:obs_connection,
        user: user,
        host: 'localhost',
        port: 4455,
        connected: false
      )
    end

    context 'with valid authentication' do
      it 'returns success status' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: true
        }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'updates the connection' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: true,
          version: '5.1.0'
        }, headers: valid_headers

        obs_connection.reload
        expect(obs_connection.connected).to be true
        expect(obs_connection.version).to eq('5.1.0')
      end

      it 'returns updated connection data' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: true
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('obs_connection')
        expect(json_response['obs_connection']['connected']).to be true
      end

      it 'returns success message' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: true
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('OBS connection updated successfully')
      end

      it 'sets last_connected_at when connected becomes true' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: true
        }, headers: valid_headers

        obs_connection.reload
        expect(obs_connection.last_connected_at).not_to be_nil
      end

      it 'sets disconnected_at when connected becomes false' do
        obs_connection.update(connected: true)

        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: false
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['obs_connection']).to have_key('disconnected_at')
      end
    end

    context 'when connection does not exist' do
      let(:user_without_obs) { create(:user) }

      it 'returns not found status' do
        patch "/api/v1/users/#{user_without_obs.id}/obs_connection", params: {
          connected: true
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        patch "/api/v1/users/#{user_without_obs.id}/obs_connection", params: {
          connected: true
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OBS connection not found')
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable entity status' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          port: -1
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error details' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          port: -1
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to update OBS connection')
        expect(json_response).to have_key('details')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        patch '/api/v1/users/99999/obs_connection', params: {
          connected: true
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        patch "/api/v1/users/#{user.id}/obs_connection", params: {
          connected: true
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/users/:user_id/obs_connection' do
    let(:user) { create(:user) }
    let!(:obs_connection) { create(:obs_connection, user: user) }

    context 'with valid authentication' do
      it 'returns success status' do
        delete "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'deletes the connection' do
        expect {
          delete "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers
        }.to change(ObsConnection, :count).by(-1)
      end

      it 'returns success message' do
        delete "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('OBS connection deleted successfully')
      end
    end

    context 'when connection does not exist' do
      let(:user_without_obs) { create(:user) }

      it 'returns not found status' do
        delete "/api/v1/users/#{user_without_obs.id}/obs_connection", headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        delete "/api/v1/users/#{user_without_obs.id}/obs_connection", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OBS connection not found')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        delete '/api/v1/users/99999/obs_connection', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        delete "/api/v1/users/#{user.id}/obs_connection", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not delete connection' do
        expect {
          delete "/api/v1/users/#{user.id}/obs_connection", headers: invalid_headers
        }.not_to change(ObsConnection, :count)
      end
    end
  end

  describe 'GET /api/v1/users/:user_id/obs_connection/stats' do
    let(:user) { create(:user) }
    let!(:obs_connection) do
      create(:obs_connection,
        user: user,
        connected: true,
        last_connected_at: 2.hours.ago
      )
    end

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/users/#{user.id}/obs_connection/stats", headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns connection statistics' do
        get "/api/v1/users/#{user.id}/obs_connection/stats", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('stats')
        stats = json_response['stats']
        expect(stats).to include(
          'total_connections',
          'total_uptime_seconds',
          'average_session_duration',
          'last_connected_at',
          'disconnected_at',
          'currently_connected'
        )
      end

      it 'includes current connection status' do
        get "/api/v1/users/#{user.id}/obs_connection/stats", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['stats']['currently_connected']).to be true
      end
    end

    context 'when connection does not exist' do
      let(:user_without_obs) { create(:user) }

      it 'returns not found status' do
        get "/api/v1/users/#{user_without_obs.id}/obs_connection/stats", headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get "/api/v1/users/#{user_without_obs.id}/obs_connection/stats", headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('OBS connection not found')
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        get '/api/v1/users/99999/obs_connection/stats', headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/users/#{user.id}/obs_connection/stats", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'JSON response format' do
    let(:user) { create(:user) }
    let!(:obs_connection) { create(:obs_connection, user: user) }

    it 'returns valid JSON' do
      get "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      get "/api/v1/users/#{user.id}/obs_connection", headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end

  describe 'authorization with different header formats' do
    let(:user) { create(:user) }
    let!(:obs_connection) { create(:obs_connection, user: user) }

    it 'accepts X-API-Key header' do
      get "/api/v1/users/#{user.id}/obs_connection", headers: { 'X-API-Key' => valid_api_key }

      expect(response).to have_http_status(:ok)
    end

    it 'accepts api_key parameter' do
      get "/api/v1/users/#{user.id}/obs_connection", params: { api_key: valid_api_key }

      expect(response).to have_http_status(:ok)
    end
  end
end
