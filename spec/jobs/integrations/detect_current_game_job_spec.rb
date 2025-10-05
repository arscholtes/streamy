require 'rails_helper'

RSpec.describe Integrations::DetectCurrentGameJob, type: :job do
  let(:user) { create(:user) }
  let(:steam_account) { create(:steam_account, user: user) }
  let(:stream) { create(:stream, user: user, status: 'live') }

  describe '#perform' do
    context 'when stream is live and user has Steam connected' do
      let(:recent_game_response) do
        {
          'games' => [
            {
              'appid' => 570,
              'name' => 'Dota 2',
              'img_icon_url' => 'abc123',
              'rtime_last_played' => (Time.now.to_i - 60) # Played 1 minute ago
            }
          ]
        }
      end

      before do
        allow_any_instance_of(Integrations::SteamApiClient)
          .to receive(:get_recent_games).and_return(recent_game_response)
      end

      it 'creates a new game session' do
        expect {
          described_class.new.perform(stream.id)
        }.to change(GameSession, :count).by(1)
      end

      it 'creates game session with correct attributes' do
        described_class.new.perform(stream.id)

        session = GameSession.last
        expect(session.user).to eq(user)
        expect(session.stream).to eq(stream)
        expect(session.platform).to eq('steam')
        expect(session.game_name).to eq('Dota 2')
        expect(session.game_id).to eq('570')
      end

      it 'creates or updates steam game record' do
        expect {
          described_class.new.perform(stream.id)
        }.to change(SteamGame, :count).by(1)

        steam_game = SteamGame.last
        expect(steam_game.app_id).to eq(570)
        expect(steam_game.name).to eq('Dota 2')
      end

      it 'ends previous game sessions before creating new one' do
        old_session = create(:game_session, user: user, stream: stream, ended_at: nil)

        described_class.new.perform(stream.id)

        expect(old_session.reload.ended_at).not_to be_nil
      end

      it 're-enqueues itself after 30 seconds if stream is still live' do
        expect {
          described_class.new.perform(stream.id)
        }.to have_enqueued_job(described_class).with(stream.id).at(30.seconds.from_now)
      end

      it 'does not touch existing session if game is the same' do
        create(:steam_game, steam_account: steam_account, app_id: 570, name: 'Dota 2')
        existing_session = create(:game_session,
          user: user,
          stream: stream,
          game_id: '570',
          platform: 'steam',
          ended_at: nil
        )

        expect {
          described_class.new.perform(stream.id)
        }.not_to change(GameSession, :count)

        # Should touch the session to update updated_at
        expect(existing_session.reload.updated_at).to be > 1.second.ago
      end
    end

    context 'when stream is offline' do
      before do
        stream.update(status: 'offline')
      end

      it 'does not create game session' do
        expect {
          described_class.new.perform(stream.id)
        }.not_to change(GameSession, :count)
      end

      it 'does not re-enqueue itself' do
        expect {
          described_class.new.perform(stream.id)
        }.not_to have_enqueued_job(described_class)
      end
    end

    context 'when user does not have Steam connected' do
      before do
        steam_account.destroy
      end

      it 'does not create game session' do
        expect {
          described_class.new.perform(stream.id)
        }.not_to change(GameSession, :count)
      end
    end

    context 'when game was not played recently' do
      let(:old_game_response) do
        {
          'games' => [
            {
              'appid' => 570,
              'name' => 'Dota 2',
              'rtime_last_played' => (Time.now.to_i - 600) # Played 10 minutes ago
            }
          ]
        }
      end

      before do
        allow_any_instance_of(Integrations::SteamApiClient)
          .to receive(:get_recent_games).and_return(old_game_response)
      end

      it 'does not create game session' do
        expect {
          described_class.new.perform(stream.id)
        }.not_to change(GameSession, :count)
      end
    end

    context 'when no recent games' do
      before do
        allow_any_instance_of(Integrations::SteamApiClient)
          .to receive(:get_recent_games).and_return({ 'games' => [] })
      end

      it 'does not create game session' do
        expect {
          described_class.new.perform(stream.id)
        }.not_to change(GameSession, :count)
      end
    end

    context 'when stream is not found' do
      it 'logs and does not raise error' do
        expect(Rails.logger).to receive(:info).with(/Stream 99999 not found/)

        expect {
          described_class.new.perform(99999)
        }.not_to raise_error
      end
    end

    context 'when API error occurs' do
      before do
        allow_any_instance_of(Integrations::SteamApiClient)
          .to receive(:get_recent_games).and_raise(Integrations::APIError, 'API Error')
      end

      it 'logs error and does not raise' do
        expect(Rails.logger).to receive(:error).with(/Game detection error/)

        expect {
          described_class.new.perform(stream.id)
        }.not_to raise_error
      end
    end
  end
end
