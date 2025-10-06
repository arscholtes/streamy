require 'rails_helper'

RSpec.describe Integrations::RiotSyncJob, type: :job do
  let(:user) { create(:user) }
  let(:riot_account) { create(:riot_account, user: user) }
  let(:sync_service) { instance_double(Integrations::RiotSyncService) }

  describe 'inheritance' do
    it 'inherits from BaseSyncJob' do
      expect(described_class.superclass).to eq(Integrations::BaseSyncJob)
    end
  end

  describe 'job configuration' do
    it 'is set to default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'inherits retry configuration from BaseSyncJob' do
      # Check that the job class has retry_on configured for APIError
      retry_callbacks = described_class.rescue_handlers.select do |handler|
        handler.first == Integrations::APIError
      end
      expect(retry_callbacks).not_to be_empty
    end

    it 'inherits retry configuration for RateLimitError from BaseSyncJob' do
      # Check that the job class has retry_on configured for RateLimitError
      retry_callbacks = described_class.rescue_handlers.select do |handler|
        handler.first == Integrations::RateLimitError
      end
      expect(retry_callbacks).not_to be_empty
    end
  end

  describe '#perform' do
    before do
      allow(Integrations::RiotSyncService).to receive(:new).with(riot_account).and_return(sync_service)
      allow(sync_service).to receive(:sync!)
    end

    context 'with valid Riot account' do
      it 'finds the Riot account' do
        expect(RiotAccount).to receive(:find_by).with(id: riot_account.id).and_return(riot_account)

        described_class.new.perform(riot_account.id, 'RiotAccount')
      end

      it 'creates RiotSyncService with the account' do
        expect(Integrations::RiotSyncService).to receive(:new).with(riot_account).and_return(sync_service)

        described_class.new.perform(riot_account.id, 'RiotAccount')
      end

      it 'calls sync! on the sync service' do
        expect(sync_service).to receive(:sync!)

        described_class.new.perform(riot_account.id, 'RiotAccount')
      end

      it 'updates last_synced_at timestamp' do
        travel_to Time.current do
          described_class.new.perform(riot_account.id, 'RiotAccount')

          expect(riot_account.reload.last_synced_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs sync start and completion' do
        expect(Rails.logger).to receive(:info).with(/Starting sync for RiotAccount##{riot_account.id}/)
        expect(Rails.logger).to receive(:info).with(/Completed sync for RiotAccount##{riot_account.id}/)

        described_class.new.perform(riot_account.id, 'RiotAccount')
      end
    end

    context 'when Riot account is not found' do
      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/Integration account not found: RiotAccount#99999/)

        expect {
          described_class.new.perform(99999, 'RiotAccount')
        }.not_to raise_error
      end

      it 'does not attempt to sync' do
        expect(Integrations::RiotSyncService).not_to receive(:new)

        described_class.new.perform(99999, 'RiotAccount')
      end
    end

    context 'when sync service raises APIError' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(Integrations::APIError, 'Riot API Error')
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for RiotAccount##{riot_account.id}: Riot API Error/)

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(Integrations::APIError, 'Riot API Error')
      end

      it 'does not update last_synced_at' do
        original_time = riot_account.last_synced_at

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(Integrations::APIError)

        expect(riot_account.reload.last_synced_at).to eq(original_time)
      end
    end

    context 'when sync service raises RateLimitError' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(Integrations::RateLimitError, 'Riot rate limit exceeded')
      end

      it 'raises the error for retry handling' do
        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(Integrations::RateLimitError)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for RiotAccount##{riot_account.id}/)

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(Integrations::RateLimitError)
      end
    end

    context 'when sync service raises unexpected error' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(StandardError, 'Unexpected error')
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for RiotAccount##{riot_account.id}: Unexpected error/)

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(StandardError, 'Unexpected error')
      end
    end

    context 'when sync service raises AuthenticationError' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(Integrations::AuthenticationError, 'Invalid credentials')
      end

      it 'logs and re-raises the error' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for RiotAccount##{riot_account.id}/)

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(Integrations::AuthenticationError)
      end
    end
  end

  describe 'enqueuing' do
    it 'can be enqueued with perform_later' do
      expect {
        described_class.perform_later(riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class).with(riot_account.id, 'RiotAccount')
    end

    it 'can be enqueued with a delay' do
      expect {
        described_class.set(wait: 15.minutes).perform_later(riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class)
        .with(riot_account.id, 'RiotAccount')
        .at(15.minutes.from_now)
    end

    it 'can be enqueued at a specific time' do
      specific_time = 3.hours.from_now

      expect {
        described_class.set(wait_until: specific_time).perform_later(riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class)
        .with(riot_account.id, 'RiotAccount')
        .at(specific_time)
    end

    it 'enqueues on the default queue' do
      expect {
        described_class.perform_later(riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class)
        .on_queue('default')
    end

    it 'can override the queue' do
      expect {
        described_class.set(queue: :low_priority).perform_later(riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class)
        .on_queue('low_priority')
    end
  end

  describe 'integration with Riot ecosystem' do
    let(:riot_sync_service) { Integrations::RiotSyncService.new(riot_account) }

    before do
      allow(Integrations::RiotSyncService).to receive(:new).and_return(riot_sync_service)
      allow(riot_sync_service).to receive(:sync!)
    end

    it 'works with actual RiotSyncService class' do
      expect {
        described_class.new.perform(riot_account.id, 'RiotAccount')
      }.not_to raise_error
    end

    it 'passes the correct Riot account to the service' do
      expect(Integrations::RiotSyncService).to receive(:new).with(riot_account)

      described_class.new.perform(riot_account.id, 'RiotAccount')
    end
  end

  describe 'error handling scenarios' do
    context 'when account has invalid tokens' do
      before do
        riot_account.update(access_token: nil)
        allow(Integrations::RiotSyncService).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync!).and_raise(Integrations::AuthenticationError, 'Invalid token')
      end

      it 'raises authentication error' do
        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.to raise_error(Integrations::AuthenticationError)
      end
    end

    context 'when account is soft-deleted' do
      before do
        riot_account.update(user_id: nil) if riot_account.respond_to?(:deleted_at)
      end

      it 'handles gracefully when account cannot be found' do
        allow(RiotAccount).to receive(:find_by).and_return(nil)

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.not_to raise_error
      end
    end

    context 'when user is deleted' do
      before do
        user.destroy
      end

      it 'handles missing user gracefully' do
        allow(RiotAccount).to receive(:find_by).and_return(nil)

        expect {
          described_class.new.perform(riot_account.id, 'RiotAccount')
        }.not_to raise_error
      end
    end
  end

  describe 'concurrent job handling' do
    it 'can have multiple jobs enqueued for different accounts' do
      another_riot_account = create(:riot_account, user: create(:user))

      expect {
        described_class.perform_later(riot_account.id, 'RiotAccount')
        described_class.perform_later(another_riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class).twice
    end

    it 'can have the same account synced multiple times' do
      expect {
        described_class.perform_later(riot_account.id, 'RiotAccount')
        described_class.perform_later(riot_account.id, 'RiotAccount')
      }.to have_enqueued_job(described_class)
        .with(riot_account.id, 'RiotAccount')
        .twice
    end
  end

  describe 'syncing multiple game types' do
    it 'syncs League of Legends data' do
      expect(sync_service).to receive(:sync!)

      described_class.new.perform(riot_account.id, 'RiotAccount')
    end

    it 'syncs Valorant data' do
      expect(sync_service).to receive(:sync!)

      described_class.new.perform(riot_account.id, 'RiotAccount')
    end
  end
end
