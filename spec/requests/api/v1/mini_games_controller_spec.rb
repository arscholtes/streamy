require 'rails_helper'

RSpec.describe Api::V1::MiniGamesController, type: :request do
  let(:valid_api_key) { ENV['DISCORD_BOT_API_KEY'] || 'test_api_key' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_api_key}" } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_key' } }

  before do
    ENV['DISCORD_BOT_API_KEY'] ||= 'test_api_key'
  end

  describe 'POST /api/v1/mini_games/record' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user, points: 100, total_earned: 100, total_spent: 0) }

    context 'with valid authentication and parameters' do
      context 'when winning a game' do
        let(:win_params) do
          {
            user_id: user.id,
            game_type: 'coinflip',
            bet_amount: 10,
            result: 'win',
            winnings: 20,
            metadata: { choice: 'heads' }
          }
        end

        it 'returns created status' do
          post '/api/v1/mini_games/record', params: win_params, headers: valid_headers

          expect(response).to have_http_status(:created)
        end

        it 'creates a new game session record' do
          expect {
            post '/api/v1/mini_games/record', params: win_params, headers: valid_headers
          }.to change(MiniGameSession, :count).by(1)
        end

        it 'returns the session data' do
          post '/api/v1/mini_games/record', params: win_params, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('session')
          expect(json_response['session']).to include(
            'id',
            'game_type',
            'result',
            'profit',
            'new_balance'
          )
        end

        it 'adds winnings to loyalty points' do
          expect {
            post '/api/v1/mini_games/record', params: win_params, headers: valid_headers
            loyalty_points.reload
          }.to change { loyalty_points.points }.by(10) # profit = winnings - bet_amount
        end

        it 'calculates profit correctly' do
          post '/api/v1/mini_games/record', params: win_params, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['session']['profit']).to eq(10) # 20 - 10
        end

        it 'includes new balance in response' do
          post '/api/v1/mini_games/record', params: win_params, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['session']['new_balance']).to eq(110)
        end
      end

      context 'when losing a game' do
        let(:loss_params) do
          {
            user_id: user.id,
            game_type: 'slots',
            bet_amount: 15,
            result: 'loss',
            winnings: 0,
            metadata: {}
          }
        end

        it 'returns created status' do
          post '/api/v1/mini_games/record', params: loss_params, headers: valid_headers

          expect(response).to have_http_status(:created)
        end

        it 'creates a new game session record' do
          expect {
            post '/api/v1/mini_games/record', params: loss_params, headers: valid_headers
          }.to change(MiniGameSession, :count).by(1)
        end

        it 'deducts bet amount from loyalty points' do
          expect {
            post '/api/v1/mini_games/record', params: loss_params, headers: valid_headers
            loyalty_points.reload
          }.to change { loyalty_points.points }.by(-15)
        end

        it 'calculates negative profit correctly' do
          post '/api/v1/mini_games/record', params: loss_params, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['session']['profit']).to eq(-15) # 0 - 15
        end

        it 'includes new balance in response' do
          post '/api/v1/mini_games/record', params: loss_params, headers: valid_headers

          json_response = JSON.parse(response.body)
          expect(json_response['session']['new_balance']).to eq(85)
        end
      end

      context 'with different game types' do
        it 'records coinflip game' do
          post '/api/v1/mini_games/record', params: {
            user_id: user.id,
            game_type: 'coinflip',
            bet_amount: 10,
            result: 'win',
            winnings: 20
          }, headers: valid_headers

          session = MiniGameSession.last
          expect(session.game_type).to eq('coinflip')
        end

        it 'records roulette game' do
          post '/api/v1/mini_games/record', params: {
            user_id: user.id,
            game_type: 'roulette',
            bet_amount: 10,
            result: 'win',
            winnings: 20
          }, headers: valid_headers

          session = MiniGameSession.last
          expect(session.game_type).to eq('roulette')
        end

        it 'records slots game' do
          post '/api/v1/mini_games/record', params: {
            user_id: user.id,
            game_type: 'slots',
            bet_amount: 10,
            result: 'win',
            winnings: 20
          }, headers: valid_headers

          session = MiniGameSession.last
          expect(session.game_type).to eq('slots')
        end
      end

      context 'when user has no loyalty points' do
        let(:user_without_points) { create(:user) }

        it 'creates loyalty points automatically' do
          expect {
            post '/api/v1/mini_games/record', params: {
              user_id: user_without_points.id,
              game_type: 'coinflip',
              bet_amount: 10,
              result: 'win',
              winnings: 20
            }, headers: valid_headers
          }.to change(LoyaltyPoint, :count).by(1)
        end
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid game type' do
        post '/api/v1/mini_games/record', params: {
          user_id: user.id,
          game_type: 'invalid_game',
          bet_amount: 10,
          result: 'win',
          winnings: 20
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error for invalid result' do
        post '/api/v1/mini_games/record', params: {
          user_id: user.id,
          game_type: 'coinflip',
          bet_amount: 10,
          result: 'invalid_result',
          winnings: 20
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error for negative bet amount' do
        post '/api/v1/mini_games/record', params: {
          user_id: user.id,
          game_type: 'coinflip',
          bet_amount: -10,
          result: 'win',
          winnings: 20
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error for zero bet amount' do
        post '/api/v1/mini_games/record', params: {
          user_id: user.id,
          game_type: 'coinflip',
          bet_amount: 0,
          result: 'win',
          winnings: 20
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error for missing required fields' do
        post '/api/v1/mini_games/record', params: {
          user_id: user.id,
          game_type: 'coinflip'
        }, headers: valid_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        post '/api/v1/mini_games/record', params: {
          user_id: 99999,
          game_type: 'coinflip',
          bet_amount: 10,
          result: 'win',
          winnings: 20
        }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        post '/api/v1/mini_games/record', params: {
          user_id: 99999,
          game_type: 'coinflip',
          bet_amount: 10,
          result: 'win',
          winnings: 20
        }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post '/api/v1/mini_games/record', params: {
          user_id: user.id,
          game_type: 'coinflip',
          bet_amount: 10,
          result: 'win',
          winnings: 20
        }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create game session' do
        expect {
          post '/api/v1/mini_games/record', params: {
            user_id: user.id,
            game_type: 'coinflip',
            bet_amount: 10,
            result: 'win',
            winnings: 20
          }, headers: invalid_headers
        }.not_to change(MiniGameSession, :count)
      end
    end
  end

  describe 'GET /api/v1/mini_games/stats' do
    let(:user) { create(:user) }
    let!(:win_session1) { create(:mini_game_session, user: user, game_type: 'coinflip', bet_amount: 10, result: 'win', winnings: 20) }
    let!(:win_session2) { create(:mini_game_session, user: user, game_type: 'coinflip', bet_amount: 15, result: 'win', winnings: 30) }
    let!(:loss_session) { create(:mini_game_session, user: user, game_type: 'slots', bet_amount: 20, result: 'loss', winnings: 0) }

    context 'with valid authentication' do
      it 'returns success status' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns stats for all games' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('stats')
        stats = json_response['stats']
        expect(stats['total_games']).to eq(3)
        expect(stats['total_won']).to eq(2)
        expect(stats['total_lost']).to eq(1)
      end

      it 'calculates win rate correctly' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        stats = json_response['stats']
        expect(stats['win_rate']).to eq(66.67) # 2/3 * 100
      end

      it 'calculates total wagered correctly' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        stats = json_response['stats']
        expect(stats['total_wagered']).to eq(45) # 10 + 15 + 20
      end

      it 'calculates total winnings correctly' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        stats = json_response['stats']
        expect(stats['total_winnings']).to eq(50) # 20 + 30 + 0
      end

      it 'calculates net profit correctly' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        stats = json_response['stats']
        expect(stats['net_profit']).to eq(5) # 50 - 45
      end

      it 'includes all required stats fields' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: valid_headers

        json_response = JSON.parse(response.body)
        stats = json_response['stats']
        expect(stats).to include(
          'total_games',
          'total_won',
          'total_lost',
          'win_rate',
          'total_wagered',
          'total_winnings',
          'net_profit'
        )
      end

      context 'with game_type filter' do
        it 'returns stats only for specified game type' do
          get "/api/v1/mini_games/stats", params: { user_id: user.id, game_type: 'coinflip' }, headers: valid_headers

          json_response = JSON.parse(response.body)
          stats = json_response['stats']
          expect(stats['total_games']).to eq(2) # Only coinflip games
          expect(stats['total_wagered']).to eq(25) # 10 + 15
        end

        it 'calculates win rate for filtered game type' do
          get "/api/v1/mini_games/stats", params: { user_id: user.id, game_type: 'coinflip' }, headers: valid_headers

          json_response = JSON.parse(response.body)
          stats = json_response['stats']
          expect(stats['win_rate']).to eq(100.0) # Both coinflip games were wins
        end
      end

      context 'when user has no game sessions' do
        let(:user_without_games) { create(:user) }

        it 'returns zero stats' do
          get "/api/v1/mini_games/stats", params: { user_id: user_without_games.id }, headers: valid_headers

          json_response = JSON.parse(response.body)
          stats = json_response['stats']
          expect(stats['total_games']).to eq(0)
          expect(stats['win_rate']).to eq(0)
        end
      end
    end

    context 'when user does not exist' do
      it 'returns not found status' do
        get "/api/v1/mini_games/stats", params: { user_id: 99999 }, headers: valid_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get "/api/v1/mini_games/stats", params: { user_id: 99999 }, headers: valid_headers

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get "/api/v1/mini_games/stats", params: { user_id: user.id }, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'JSON response format' do
    let(:user) { create(:user) }
    let!(:loyalty_points) { create(:loyalty_point, user: user, points: 100) }

    it 'returns valid JSON' do
      post '/api/v1/mini_games/record', params: {
        user_id: user.id,
        game_type: 'coinflip',
        bet_amount: 10,
        result: 'win',
        winnings: 20
      }, headers: valid_headers

      expect { JSON.parse(response.body) }.not_to raise_error
    end

    it 'sets correct content type' do
      post '/api/v1/mini_games/record', params: {
        user_id: user.id,
        game_type: 'coinflip',
        bet_amount: 10,
        result: 'win',
        winnings: 20
      }, headers: valid_headers

      expect(response.content_type).to match(/application\/json/)
    end
  end
end
