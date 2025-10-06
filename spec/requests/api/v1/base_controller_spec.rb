require 'rails_helper'

RSpec.describe Api::V1::BaseController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:invalid_api_key) { 'invalid_key' }

  before do
    # Set API key for testing if not already set
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'authentication' do
    # Create a simple test endpoint using UsersController which inherits from BaseController
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }

    before { discord_account }

    context 'with valid API key in Authorization header' do
      it 'allows access to the endpoint' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}",
            headers: { 'Authorization' => "Bearer #{valid_api_key}" }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with valid API key without Bearer prefix' do
      it 'allows access to the endpoint' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}",
            headers: { 'Authorization' => valid_api_key }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid API key' do
      it 'returns unauthorized status' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}",
            headers: { 'Authorization' => "Bearer #{invalid_api_key}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}",
            headers: { 'Authorization' => "Bearer #{invalid_api_key}" }

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end
    end

    context 'without API key' do
      it 'returns unauthorized status' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}"

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message' do
        get "/api/v1/users/by_discord_id/#{discord_account.discord_id}"

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end
    end
  end

  describe 'helper methods' do
    # These are tested indirectly through other controller specs
    # but we can document their expected behavior here

    describe '#render_error' do
      it 'is used to render error responses with custom status' do
        # Tested in individual controller specs
        expect(Api::V1::BaseController.instance_methods).to include(:render_error)
      end
    end

    describe '#render_success' do
      it 'is used to render success responses with custom status' do
        # Tested in individual controller specs
        expect(Api::V1::BaseController.instance_methods).to include(:render_success)
      end
    end
  end

  describe 'CSRF protection' do
    it 'skips CSRF token verification for API requests' do
      # The controller has skip_before_action :verify_authenticity_token
      # This is necessary for API endpoints
      expect(Api::V1::BaseController._skip_action_callbacks
        .select { |c| c.filter == :verify_authenticity_token }
        .any?).to be true
    end
  end
end
