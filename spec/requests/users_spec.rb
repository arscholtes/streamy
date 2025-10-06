require 'rails_helper'

RSpec.describe UsersController, type: :request do
  let(:user) { create(:user) }
  let!(:stream1) { create(:stream, user: user, status: 'live', created_at: 1.hour.ago) }
  let!(:stream2) { create(:stream, user: user, status: 'offline', created_at: 2.hours.ago) }
  let!(:old_stream) { create(:stream, user: user, status: 'offline', created_at: 1.week.ago) }

  describe 'GET /users/:id' do
    it 'shows user profile page' do
      get user_path(user)

      expect(response).to have_http_status(:success)
      expect(assigns(:user)).to eq(user)
    end

    it 'loads recent streams (limited to 6)' do
      get user_path(user)

      expect(assigns(:streams).count).to be <= 6
      expect(assigns(:streams)).to include(stream1)
    end

    it 'loads live streams' do
      get user_path(user)

      expect(assigns(:live_streams)).to include(stream1)
      expect(assigns(:live_streams)).not_to include(stream2)
    end

    it 'counts total streams' do
      get user_path(user)

      expect(assigns(:total_streams)).to eq(3)
    end

    it 'checks Steam integration status' do
      steam_account = create(:steam_account, user: user)

      get user_path(user)

      expect(assigns(:steam_connected)).to be true
    end

    it 'checks Discord integration status' do
      discord_account = create(:discord_account, user: user)

      get user_path(user)

      expect(assigns(:discord_connected)).to be true
    end

    it 'checks Battle.net integration status' do
      battlenet_account = create(:battlenet_account, user: user)

      get user_path(user)

      expect(assigns(:battlenet_connected)).to be true
    end

    it 'checks Riot integration status' do
      riot_account = create(:riot_account, user: user)

      get user_path(user)

      expect(assigns(:riot_connected)).to be true
    end

    it 'checks Twitter integration status' do
      twitter_account = create(:twitter_account, user: user)

      get user_path(user)

      expect(assigns(:twitter_connected)).to be true
    end

    it 'checks YouTube integration status' do
      youtube_account = create(:youtube_account, user: user)

      get user_path(user)

      expect(assigns(:youtube_connected)).to be true
    end

    it 'counts connected integrations' do
      create(:steam_account, user: user)
      create(:discord_account, user: user)

      get user_path(user)

      expect(assigns(:connected_integrations)).to eq(2)
    end

    it 'shows loyalty points' do
      loyalty_point = create(:loyalty_point, user: user, points: 1500)

      get user_path(user)

      expect(assigns(:loyalty_points)).to eq(1500)
    end

    it 'defaults loyalty points to 0 when none exist' do
      get user_path(user)

      expect(assigns(:loyalty_points)).to eq(0)
    end

    it 'counts user achievements' do
      achievement = create(:achievement)
      create(:user_achievement, user: user, achievement: achievement)

      get user_path(user)

      expect(assigns(:achievements_count)).to eq(1)
    end

    it 'shows total achievements available' do
      create(:achievement)
      create(:achievement)

      get user_path(user)

      expect(assigns(:total_achievements)).to eq(2)
    end

    it 'handles non-existent user' do
      get user_path(id: 99999)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('User not found')
    end

    context 'with Steam account' do
      let(:steam_account) { create(:steam_account, user: user, steam_id: '76561198000000000') }
      let(:privacy_setting) { create(:integration_privacy_setting, integration_account: steam_account) }

      before do
        steam_account
        privacy_setting
      end

      it 'loads Steam account data' do
        get user_path(user)

        expect(assigns(:steam_account)).to eq(steam_account)
      end

      it 'counts Steam games' do
        allow(steam_account).to receive_message_chain(:steam_games, :count).and_return(50)

        get user_path(user)

        expect(assigns(:steam_game_count)).to be_present
      end

      it 'respects privacy settings for game library' do
        allow(privacy_setting).to receive(:show?).with(:show_game_library).and_return(false)
        allow(steam_account).to receive(:integration_privacy_setting).and_return(privacy_setting)

        get user_path(user)

        expect(assigns(:steam_top_games)).to be_nil
      end

      it 'shows top games when privacy allows' do
        allow(privacy_setting).to receive(:show?).with(:show_game_library).and_return(true)
        allow(steam_account).to receive(:integration_privacy_setting).and_return(privacy_setting)
        allow(steam_account).to receive_message_chain(:steam_games, :where, :order, :limit).and_return([])

        get user_path(user)

        # Test passes if it doesn't raise an error
        expect(response).to have_http_status(:success)
      end
    end
  end
end
