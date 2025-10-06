require 'rails_helper'

RSpec.describe Integrations::SteamSyncJob, type: :job do
  let(:user) { create(:user) }
  let(:steam_account) { create(:steam_account, user: user) }
  let(:sync_service) { instance_double(Integrations::SteamSyncService) }

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
      allow(Integrations::SteamSyncService).to receive(:new).with(steam_account).and_return(sync_service)
      allow(sync_service).to receive(:sync!)
    end

    context 'with valid Steam account' do
      it 'finds the Steam account' do
        expect(SteamAccount).to receive(:find_by).with(id: steam_account.id).and_return(steam_account)

        described_class.new.perform(steam_account.id, 'SteamAccount')
      end

      it 'creates SteamSyncService with the account' do
        expect(Integrations::SteamSyncService).to receive(:new).with(steam_account).and_return(sync_service)

        described_class.new.perform(steam_account.id, 'SteamAccount')
      end

      it 'calls sync! on the sync service' do
        expect(sync_service).to receive(:sync!)

        described_class.new.perform(steam_account.id, 'SteamAccount')
      end

      it 'updates last_synced_at timestamp' do
        travel_to Time.current do
          described_class.new.perform(steam_account.id, 'SteamAccount')

          expect(steam_account.reload.last_synced_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs sync start and completion' do
        expect(Rails.logger).to receive(:info).with(/Starting sync for SteamAccount##{steam_account.id}/)
        expect(Rails.logger).to receive(:info).with(/Completed sync for SteamAccount##{steam_account.id}/)

        described_class.new.perform(steam_account.id, 'SteamAccount')
      end
    end

    context 'when Steam account is not found' do
      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/Integration account not found: SteamAccount#99999/)

        expect {
          described_class.new.perform(99999, 'SteamAccount')
        }.not_to raise_error
      end

      it 'does not attempt to sync' do
        expect(Integrations::SteamSyncService).not_to receive(:new)

        described_class.new.perform(99999, 'SteamAccount')
      end
    end

    context 'when sync service raises APIError' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(Integrations::APIError, 'Steam API Error')
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for SteamAccount##{steam_account.id}: Steam API Error/)

        expect {
          described_class.new.perform(steam_account.id, 'SteamAccount')
        }.to raise_error(Integrations::APIError, 'Steam API Error')
      end

      it 'does not update last_synced_at' do
        original_time = steam_account.last_synced_at

        expect {
          described_class.new.perform(steam_account.id, 'SteamAccount')
        }.to raise_error(Integrations::APIError)

        expect(steam_account.reload.last_synced_at).to eq(original_time)
      end
    end

    context 'when sync service raises RateLimitError' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(Integrations::RateLimitError, 'Rate limited')
      end

      it 'raises the error for retry handling' do
        expect {
          described_class.new.perform(steam_account.id, 'SteamAccount')
        }.to raise_error(Integrations::RateLimitError)
      end
    end

    context 'when sync service raises unexpected error' do
      before do
        allow(sync_service).to receive(:sync!).and_raise(StandardError, 'Unexpected error')
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for SteamAccount##{steam_account.id}: Unexpected error/)

        expect {
          described_class.new.perform(steam_account.id, 'SteamAccount')
        }.to raise_error(StandardError, 'Unexpected error')
      end
    end
  end

  describe 'enqueuing' do
    it 'can be enqueued with perform_later' do
      expect {
        described_class.perform_later(steam_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class).with(steam_account.id, 'SteamAccount')
    end

    it 'can be enqueued with a delay' do
      expect {
        described_class.set(wait: 5.minutes).perform_later(steam_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class)
        .with(steam_account.id, 'SteamAccount')
        .at(5.minutes.from_now)
    end

    it 'can be enqueued at a specific time' do
      specific_time = 1.day.from_now

      expect {
        described_class.set(wait_until: specific_time).perform_later(steam_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class)
        .with(steam_account.id, 'SteamAccount')
        .at(specific_time)
    end

    it 'enqueues on the default queue' do
      expect {
        described_class.perform_later(steam_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class)
        .on_queue('default')
    end
  end

  describe 'integration with Steam ecosystem' do
    let(:steam_sync_service) { Integrations::SteamSyncService.new(steam_account) }

    before do
      allow(Integrations::SteamSyncService).to receive(:new).and_return(steam_sync_service)
      allow(steam_sync_service).to receive(:sync!)
    end

    it 'works with actual SteamSyncService class' do
      expect {
        described_class.new.perform(steam_account.id, 'SteamAccount')
      }.not_to raise_error
    end

    it 'passes the correct Steam account to the service' do
      expect(Integrations::SteamSyncService).to receive(:new).with(steam_account)

      described_class.new.perform(steam_account.id, 'SteamAccount')
    end
  end

  describe 'error handling scenarios' do
    context 'when account is soft-deleted' do
      before do
        # Assuming paranoia or similar soft-delete gem
        steam_account.update(user_id: nil) if steam_account.respond_to?(:deleted_at)
      end

      it 'handles gracefully when account cannot be found' do
        allow(SteamAccount).to receive(:find_by).and_return(nil)

        expect {
          described_class.new.perform(steam_account.id, 'SteamAccount')
        }.not_to raise_error
      end
    end

    context 'when user is deleted' do
      before do
        user.destroy
      end

      it 'handles missing user gracefully' do
        allow(SteamAccount).to receive(:find_by).and_return(nil)

        expect {
          described_class.new.perform(steam_account.id, 'SteamAccount')
        }.not_to raise_error
      end
    end
  end
end
