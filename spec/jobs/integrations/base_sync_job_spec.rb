require 'rails_helper'

RSpec.describe Integrations::BaseSyncJob, type: :job do
  # Create a test sync service for testing
  let(:test_sync_service) do
    Class.new do
      attr_reader :integration_account

      def initialize(integration_account)
        @integration_account = integration_account
      end

      def sync!
        # Mock sync implementation
        true
      end
    end
  end

  # Create a test integration account class
  let(:test_integration_class) do
    Class.new(SteamAccount) do
      def self.name
        'TestIntegration'
      end

      def sync_service_class
        @sync_service_class
      end

      def sync_service_class=(klass)
        @sync_service_class = klass
      end
    end
  end

  let(:user) { create(:user) }
  let(:integration_account) { create(:steam_account, user: user) }

  before do
    # Stub the sync_service_class method
    allow(integration_account).to receive(:sync_service_class).and_return(test_sync_service)
  end

  describe 'job configuration' do
    it 'is set to default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'has retry configuration for APIError' do
      # Check that the job class has retry_on configured for APIError
      retry_callbacks = described_class.rescue_handlers.select do |handler|
        handler.first == Integrations::APIError
      end
      expect(retry_callbacks).not_to be_empty
    end

    it 'has retry configuration for RateLimitError' do
      # Check that the job class has retry_on configured for RateLimitError
      retry_callbacks = described_class.rescue_handlers.select do |handler|
        handler.first == Integrations::RateLimitError
      end
      expect(retry_callbacks).not_to be_empty
    end
  end

  describe '#perform' do
    let(:sync_service_instance) { instance_double(test_sync_service) }

    context 'with valid integration account' do
      before do
        allow(test_sync_service).to receive(:new).with(integration_account).and_return(sync_service_instance)
        allow(sync_service_instance).to receive(:sync!)
      end

      it 'finds the integration account' do
        expect(SteamAccount).to receive(:find_by).with(id: integration_account.id).and_return(integration_account)

        described_class.new.perform(integration_account.id, 'SteamAccount')
      end

      it 'calls sync! on the sync service' do
        expect(sync_service_instance).to receive(:sync!)

        described_class.new.perform(integration_account.id, 'SteamAccount')
      end

      it 'updates last_synced_at timestamp' do
        travel_to Time.current do
          described_class.new.perform(integration_account.id, 'SteamAccount')

          expect(integration_account.reload.last_synced_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs sync start' do
        expect(Rails.logger).to receive(:info).with(/Starting sync for SteamAccount##{integration_account.id}/)

        described_class.new.perform(integration_account.id, 'SteamAccount')
      end

      it 'logs sync completion' do
        expect(Rails.logger).to receive(:info).with(/Completed sync for SteamAccount##{integration_account.id}/)

        described_class.new.perform(integration_account.id, 'SteamAccount')
      end
    end

    context 'when integration account is not found' do
      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/Integration account not found: SteamAccount#99999/)

        expect {
          described_class.new.perform(99999, 'SteamAccount')
        }.not_to raise_error
      end

      it 'does not attempt to sync' do
        expect(test_sync_service).not_to receive(:new)

        described_class.new.perform(99999, 'SteamAccount')
      end
    end

    context 'when sync service class is not defined' do
      before do
        allow(integration_account).to receive(:sync_service_class).and_return(nil)
      end

      it 'logs a warning and returns early' do
        expect(Rails.logger).to receive(:warn).with(/No sync service defined for SteamAccount/)

        described_class.new.perform(integration_account.id, 'SteamAccount')
      end

      it 'does not attempt to sync' do
        expect(test_sync_service).not_to receive(:new)

        described_class.new.perform(integration_account.id, 'SteamAccount')
      end
    end

    context 'when sync service raises an error' do
      before do
        allow(test_sync_service).to receive(:new).and_return(sync_service_instance)
        allow(sync_service_instance).to receive(:sync!).and_raise(StandardError, 'Sync failed')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Sync failed for SteamAccount##{integration_account.id}: Sync failed/)

        expect {
          described_class.new.perform(integration_account.id, 'SteamAccount')
        }.to raise_error(StandardError, 'Sync failed')
      end

      it 're-raises the error' do
        expect {
          described_class.new.perform(integration_account.id, 'SteamAccount')
        }.to raise_error(StandardError, 'Sync failed')
      end

      it 'does not update last_synced_at' do
        original_time = integration_account.last_synced_at

        expect {
          described_class.new.perform(integration_account.id, 'SteamAccount')
        }.to raise_error(StandardError)

        expect(integration_account.reload.last_synced_at).to eq(original_time)
      end
    end

    context 'when sync service raises APIError' do
      before do
        allow(test_sync_service).to receive(:new).and_return(sync_service_instance)
        allow(sync_service_instance).to receive(:sync!).and_raise(Integrations::APIError, 'API Error')
      end

      it 'raises the error for retry handling' do
        expect {
          described_class.new.perform(integration_account.id, 'SteamAccount')
        }.to raise_error(Integrations::APIError)
      end
    end

    context 'when sync service raises RateLimitError' do
      before do
        allow(test_sync_service).to receive(:new).and_return(sync_service_instance)
        allow(sync_service_instance).to receive(:sync!).and_raise(Integrations::RateLimitError, 'Rate limited')
      end

      it 'raises the error for retry handling' do
        expect {
          described_class.new.perform(integration_account.id, 'SteamAccount')
        }.to raise_error(Integrations::RateLimitError)
      end
    end
  end

  describe 'enqueuing' do
    it 'can be enqueued' do
      expect {
        described_class.perform_later(integration_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class).with(integration_account.id, 'SteamAccount')
    end

    it 'can be enqueued with a delay' do
      expect {
        described_class.set(wait: 1.hour).perform_later(integration_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class)
        .with(integration_account.id, 'SteamAccount')
        .at(1.hour.from_now)
    end

    it 'can be enqueued on a specific queue' do
      expect {
        described_class.set(queue: :low_priority).perform_later(integration_account.id, 'SteamAccount')
      }.to have_enqueued_job(described_class)
        .with(integration_account.id, 'SteamAccount')
        .on_queue('low_priority')
    end
  end

  describe 'integration with different account types' do
    let(:discord_account) { create(:discord_account, user: user) }

    before do
      allow(discord_account).to receive(:sync_service_class).and_return(test_sync_service)
      allow(test_sync_service).to receive(:new).and_return(instance_double(test_sync_service, sync!: true))
    end

    it 'works with Discord accounts' do
      expect {
        described_class.new.perform(discord_account.id, 'DiscordAccount')
      }.not_to raise_error
    end

    it 'updates last_synced_at for Discord accounts' do
      travel_to Time.current do
        described_class.new.perform(discord_account.id, 'DiscordAccount')

        expect(discord_account.reload.last_synced_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
