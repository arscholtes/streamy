require 'rails_helper'

RSpec.describe Api::V1::ModerationController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_api_key}" } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'POST /api/v1/moderation/warn' do
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          discord_id: discord_account.discord_id,
          moderator_discord_id: '987654321',
          guild_id: '111222333',
          reason: 'Spam messages'
        }
      end

      it 'returns created status' do
        post '/api/v1/moderation/warn', params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'creates a new warning' do
        expect {
          post '/api/v1/moderation/warn', params: valid_params, headers: valid_headers
        }.to change(UserWarning, :count).by(1)
      end

      it 'creates a moderation action log' do
        expect {
          post '/api/v1/moderation/warn', params: valid_params, headers: valid_headers
        }.to change(ModerationAction, :count).by(1)
      end

      it 'returns warning data' do
        post '/api/v1/moderation/warn', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('warning')
        expect(json_response['warning']).to include(
          'id',
          'discord_id',
          'reason',
          'warned_at',
          'total_warnings'
        )
      end

      it 'includes total warning count' do
        create(:user_warning, discord_id: discord_account.discord_id, guild_id: '111222333')
        post '/api/v1/moderation/warn', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['warning']['total_warnings']).to eq(2)
      end

      it 'stores correct warning information' do
        post '/api/v1/moderation/warn', params: valid_params, headers: valid_headers

        warning = UserWarning.last
        expect(warning.discord_id).to eq(discord_account.discord_id)
        expect(warning.reason).to eq('Spam messages')
        expect(warning.guild_id).to eq('111222333')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/moderation/warn', params: {
          discord_id: '123456789',
          moderator_discord_id: '987654321',
          guild_id: '111222333',
          reason: 'Test'
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/moderation/warnings/:discord_id' do
    let(:discord_id) { '123456789' }
    let(:guild_id) { '111222333' }
    let!(:warning1) { create(:user_warning, discord_id: discord_id, guild_id: guild_id, reason: 'Spam') }
    let!(:warning2) { create(:user_warning, discord_id: discord_id, guild_id: guild_id, reason: 'Offensive language') }
    let!(:other_guild_warning) { create(:user_warning, discord_id: discord_id, guild_id: '999888777') }

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns warnings for the specified discord_id and guild' do
        get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['warnings'].length).to eq(2)
      end

      it 'returns warning details' do
        get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        warning = json_response['warnings'].first
        expect(warning).to include(
          'id',
          'reason',
          'moderator_discord_id',
          'warned_at'
        )
      end

      it 'includes total warning count' do
        get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['total_warnings']).to eq(2)
      end

      it 'includes discord_id and guild_id in response' do
        get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['discord_id']).to eq(discord_id)
        expect(json_response['guild_id']).to eq(guild_id)
      end

      context 'with custom limit' do
        it 'returns specified number of warnings' do
          get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id, limit: 1 }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['warnings'].length).to eq(1)
        end
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/moderation/warnings/#{discord_id}", params: { guild_id: guild_id }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/moderation/warnings/:discord_id' do
    let(:discord_id) { '123456789' }
    let(:guild_id) { '111222333' }
    let!(:warning1) { create(:user_warning, discord_id: discord_id, guild_id: guild_id) }
    let!(:warning2) { create(:user_warning, discord_id: discord_id, guild_id: guild_id) }

    context 'with valid authentication' do
      it 'returns success status' do
        delete "/api/v1/moderation/warnings/#{discord_id}", params: {
          guild_id: guild_id,
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'clears warnings for the user in the guild' do
        expect {
          delete "/api/v1/moderation/warnings/#{discord_id}", params: {
            guild_id: guild_id,
            moderator_discord_id: '987654321'
          }, headers: valid_headers
        }.to change { UserWarning.for_user(discord_id).for_guild(guild_id).count }.from(2).to(0)
      end

      it 'returns success message with count' do
        delete "/api/v1/moderation/warnings/#{discord_id}", params: {
          guild_id: guild_id,
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to include('Cleared 2 warnings')
      end

      it 'logs the moderation action' do
        expect {
          delete "/api/v1/moderation/warnings/#{discord_id}", params: {
            guild_id: guild_id,
            moderator_discord_id: '987654321'
          }, headers: valid_headers
        }.to change(ModerationAction, :count).by(1)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        delete "/api/v1/moderation/warnings/#{discord_id}", params: {
          guild_id: guild_id,
          moderator_discord_id: '987654321'
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/moderation/mute' do
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }

    context 'with valid authentication and parameters' do
      let(:valid_params) do
        {
          discord_id: discord_account.discord_id,
          moderator_discord_id: '987654321',
          guild_id: '111222333',
          reason: 'Spamming',
          duration_minutes: 60
        }
      end

      it 'returns created status' do
        post '/api/v1/moderation/mute', params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'creates a new mute record' do
        expect {
          post '/api/v1/moderation/mute', params: valid_params, headers: valid_headers
        }.to change(UserMute, :count).by(1)
      end

      it 'creates a moderation action log' do
        expect {
          post '/api/v1/moderation/mute', params: valid_params, headers: valid_headers
        }.to change(ModerationAction, :count).by(1)
      end

      it 'returns mute data' do
        post '/api/v1/moderation/mute', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('mute')
        expect(json_response['mute']).to include(
          'id',
          'discord_id',
          'reason',
          'duration_minutes',
          'muted_at',
          'ends_at',
          'active'
        )
      end

      it 'sets mute as active' do
        post '/api/v1/moderation/mute', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['mute']['active']).to be true
      end
    end

    context 'when user is already muted' do
      before do
        create(:user_mute, discord_id: discord_account.discord_id, guild_id: '111222333', active: true)
      end

      it 'returns error status' do
        post '/api/v1/moderation/mute', params: {
          discord_id: discord_account.discord_id,
          moderator_discord_id: '987654321',
          guild_id: '111222333',
          reason: 'Test',
          duration_minutes: 60
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        post '/api/v1/moderation/mute', params: {
          discord_id: discord_account.discord_id,
          moderator_discord_id: '987654321',
          guild_id: '111222333',
          reason: 'Test',
          duration_minutes: 60
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User is already muted')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/moderation/mute', params: {
          discord_id: '123456789',
          moderator_discord_id: '987654321',
          guild_id: '111222333',
          reason: 'Test',
          duration_minutes: 60
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/moderation/unmute' do
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }
    let!(:mute) { create(:user_mute, user: user, discord_id: discord_account.discord_id, guild_id: '111222333', active: true) }

    context 'with valid authentication' do
      it 'returns success status' do
        post '/api/v1/moderation/unmute', params: {
          discord_id: discord_account.discord_id,
          guild_id: '111222333',
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'unmutes the user' do
        post '/api/v1/moderation/unmute', params: {
          discord_id: discord_account.discord_id,
          guild_id: '111222333',
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        mute.reload
        expect(mute.active).to be false
      end

      it 'returns success message' do
        post '/api/v1/moderation/unmute', params: {
          discord_id: discord_account.discord_id,
          guild_id: '111222333',
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('User unmuted successfully')
      end

      it 'logs the moderation action' do
        expect {
          post '/api/v1/moderation/unmute', params: {
            discord_id: discord_account.discord_id,
            guild_id: '111222333',
            moderator_discord_id: '987654321'
          }, headers: valid_headers
        }.to change(ModerationAction, :count).by(1)
      end
    end

    context 'when user is not muted' do
      before do
        mute.update(active: false)
      end

      it 'returns not found status' do
        post '/api/v1/moderation/unmute', params: {
          discord_id: discord_account.discord_id,
          guild_id: '111222333',
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post '/api/v1/moderation/unmute', params: {
          discord_id: discord_account.discord_id,
          guild_id: '111222333',
          moderator_discord_id: '987654321'
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No active mute found for this user')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/moderation/unmute', params: {
          discord_id: discord_account.discord_id,
          guild_id: '111222333',
          moderator_discord_id: '987654321'
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/moderation/mutes/active' do
    let(:guild_id) { '111222333' }
    let!(:active_mute1) { create(:user_mute, guild_id: guild_id, active: true, muted_at: 10.minutes.ago, duration_minutes: 60) }
    let!(:active_mute2) { create(:user_mute, guild_id: guild_id, active: true, muted_at: 5.minutes.ago, duration_minutes: 30) }
    let!(:inactive_mute) { create(:user_mute, :unmuted, guild_id: guild_id) }
    let!(:other_guild_mute) { create(:user_mute, guild_id: '999888777', active: true) }

    context 'with valid authentication' do
      it 'returns success status' do
        get '/api/v1/moderation/mutes/active', params: { guild_id: guild_id }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns only active mutes for the guild' do
        get '/api/v1/moderation/mutes/active', params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['active_mutes'].length).to eq(2)
        expect(json_response['count']).to eq(2)
      end

      it 'returns mute details' do
        get '/api/v1/moderation/mutes/active', params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        mute = json_response['active_mutes'].first
        expect(mute).to include(
          'id',
          'discord_id',
          'moderator_discord_id',
          'reason',
          'duration_minutes',
          'muted_at',
          'ends_at',
          'time_remaining_minutes'
        )
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/v1/moderation/mutes/active', params: { guild_id: guild_id }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/moderation/mutes/:discord_id' do
    let(:discord_id) { '123456789' }
    let(:guild_id) { '111222333' }
    let!(:active_mute) { create(:user_mute, discord_id: discord_id, guild_id: guild_id, active: true) }

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/moderation/mutes/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns mute status when user is muted' do
        get "/api/v1/moderation/mutes/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['is_muted']).to be true
        expect(json_response['mute']).not_to be_nil
      end

      it 'returns mute details' do
        get "/api/v1/moderation/mutes/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        mute = json_response['mute']
        expect(mute).to include(
          'id',
          'reason',
          'moderator_discord_id',
          'muted_at',
          'ends_at',
          'time_remaining_minutes'
        )
      end

      context 'when user is not muted' do
        before do
          active_mute.update(active: false)
        end

        it 'returns not muted status' do
          get "/api/v1/moderation/mutes/#{discord_id}", params: { guild_id: guild_id }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['is_muted']).to be false
          expect(json_response['mute']).to be_nil
        end
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/moderation/mutes/#{discord_id}", params: { guild_id: guild_id }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/moderation/action' do
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }

    context 'with valid authentication' do
      let(:valid_params) do
        {
          action_type: 'kick',
          moderator_discord_id: '987654321',
          target_discord_id: discord_account.discord_id,
          guild_id: '111222333',
          reason: 'Rule violation',
          metadata: { rule: '3' }
        }
      end

      it 'returns created status' do
        post '/api/v1/moderation/action', params: valid_params, headers: valid_headers

        expect(response).to have_http_status(:created)
      end

      it 'creates a moderation action record' do
        expect {
          post '/api/v1/moderation/action', params: valid_params, headers: valid_headers
        }.to change(ModerationAction, :count).by(1)
      end

      it 'returns action data' do
        post '/api/v1/moderation/action', params: valid_params, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('action')
        expect(json_response['action']).to include(
          'id',
          'action_type',
          'target_discord_id',
          'moderator_discord_id',
          'reason',
          'performed_at'
        )
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/moderation/action', params: {
          action_type: 'kick',
          moderator_discord_id: '987654321',
          target_discord_id: '123456789',
          guild_id: '111222333',
          reason: 'Test'
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/moderation/actions' do
    let(:guild_id) { '111222333' }
    let!(:action1) { create(:moderation_action, guild_id: guild_id, action_type: 'warn') }
    let!(:action2) { create(:moderation_action, guild_id: guild_id, action_type: 'mute') }
    let!(:action3) { create(:moderation_action, guild_id: guild_id, action_type: 'kick') }
    let!(:other_guild_action) { create(:moderation_action, guild_id: '999888777') }

    context 'with valid authentication' do
      it 'returns success status' do
        get '/api/v1/moderation/actions', params: { guild_id: guild_id }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns actions for the specified guild' do
        get '/api/v1/moderation/actions', params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['actions'].length).to eq(3)
        expect(json_response['count']).to eq(3)
      end

      it 'returns action details' do
        get '/api/v1/moderation/actions', params: { guild_id: guild_id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        action = json_response['actions'].first
        expect(action).to include(
          'id',
          'action_type',
          'target_discord_id',
          'moderator_discord_id',
          'reason',
          'metadata',
          'performed_at'
        )
      end

      context 'with limit parameter' do
        it 'returns specified number of actions' do
          get '/api/v1/moderation/actions', params: { guild_id: guild_id, limit: 2 }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['actions'].length).to eq(2)
        end
      end

      context 'with target_discord_id filter' do
        it 'returns actions only for specified target' do
          target_id = '555666777'
          create(:moderation_action, guild_id: guild_id, target_discord_id: target_id)

          get '/api/v1/moderation/actions', params: {
            guild_id: guild_id,
            target_discord_id: target_id
          }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['actions'].length).to eq(1)
          expect(json_response['actions'].first['target_discord_id']).to eq(target_id)
        end
      end

      context 'with action_type filter' do
        it 'returns actions only of specified type' do
          get '/api/v1/moderation/actions', params: {
            guild_id: guild_id,
            action_type: 'warn'
          }, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['actions'].length).to eq(1)
          expect(json_response['actions'].first['action_type']).to eq('warn')
        end
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/v1/moderation/actions', params: { guild_id: guild_id }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'JSON response format' do
    let(:user) { create(:user) }
    let(:discord_account) { create(:discord_account, user: user, discord_id: '123456789') }

    it 'returns valid JSON' do
      post '/api/v1/moderation/warn', params: {
        discord_id: discord_account.discord_id,
        moderator_discord_id: '987654321',
        guild_id: '111222333',
        reason: 'Test'
      }, headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      post '/api/v1/moderation/warn', params: {
        discord_id: discord_account.discord_id,
        moderator_discord_id: '987654321',
        guild_id: '111222333',
        reason: 'Test'
      }, headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end
end
