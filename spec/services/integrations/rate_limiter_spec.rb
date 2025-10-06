require 'rails_helper'

RSpec.describe Integrations::RateLimiter, type: :service do
  let(:key) { 'test_api' }
  let(:limit) { 5 }
  let(:period) { 60 }
  let(:rate_limiter) { described_class.new(key: key, limit: limit, period: period) }

  before do
    # Clear Rails cache before each test
    Rails.cache.clear
  end

  describe '#initialize' do
    it 'sets the key with prefix' do
      expect(rate_limiter.key).to eq('rate_limit:test_api')
    end

    it 'sets the limit' do
      expect(rate_limiter.limit).to eq(5)
    end

    it 'sets the period' do
      expect(rate_limiter.period).to eq(60)
    end

    it 'defaults period to 60 seconds' do
      limiter = described_class.new(key: key, limit: limit)
      expect(limiter.period).to eq(60)
    end
  end

  describe '#allowed?' do
    it 'returns true when no requests have been made' do
      expect(rate_limiter.allowed?).to be true
    end

    it 'returns true when under the limit' do
      3.times { rate_limiter.record! }
      expect(rate_limiter.allowed?).to be true
    end

    it 'returns false when at the limit' do
      5.times { rate_limiter.record! }
      expect(rate_limiter.allowed?).to be false
    end

    it 'returns false when over the limit' do
      6.times { rate_limiter.record! }
      expect(rate_limiter.allowed?).to be false
    end
  end

  describe '#check!' do
    it 'returns true when allowed' do
      expect(rate_limiter.check!).to be true
    end

    it 'raises RateLimitExceededError when limit exceeded' do
      5.times { rate_limiter.record! }

      expect {
        rate_limiter.check!
      }.to raise_error(Integrations::RateLimitExceededError, /Rate limit exceeded/)
    end

    it 'includes wait time in error message' do
      5.times { rate_limiter.record! }

      expect {
        rate_limiter.check!
      }.to raise_error(Integrations::RateLimitExceededError, /Try again in \d+ seconds/)
    end
  end

  describe '#record!' do
    it 'increments the counter' do
      expect {
        rate_limiter.record!
      }.to change { rate_limiter.current_count }.from(0).to(1)
    end

    it 'increments multiple times' do
      3.times { rate_limiter.record! }
      expect(rate_limiter.current_count).to eq(3)
    end

    it 'sets expiration on first record' do
      rate_limiter.record!

      # Check that TTL is set
      expect(rate_limiter.time_until_reset).to be > 0
      expect(rate_limiter.time_until_reset).to be <= period
    end
  end

  describe '#current_count' do
    it 'returns 0 when no requests have been made' do
      expect(rate_limiter.current_count).to eq(0)
    end

    it 'returns the correct count after recordings' do
      3.times { rate_limiter.record! }
      expect(rate_limiter.current_count).to eq(3)
    end
  end

  describe '#time_until_reset' do
    it 'returns 0 when no requests have been made' do
      expect(rate_limiter.time_until_reset).to eq(0)
    end

    it 'returns time until reset after recording' do
      rate_limiter.record!
      expect(rate_limiter.time_until_reset).to be > 0
      expect(rate_limiter.time_until_reset).to be <= period
    end

    it 'decreases over time' do
      rate_limiter.record!
      initial_time = rate_limiter.time_until_reset

      sleep(1)

      later_time = rate_limiter.time_until_reset
      expect(later_time).to be < initial_time
    end
  end

  describe '#wait_if_needed' do
    it 'does not wait when under limit' do
      expect(rate_limiter).not_to receive(:sleep)
      rate_limiter.wait_if_needed
    end

    it 'waits when limit is reached' do
      5.times { rate_limiter.record! }

      # Mock sleep to avoid actual waiting in tests
      allow(rate_limiter).to receive(:sleep)

      rate_limiter.wait_if_needed

      expect(rate_limiter).to have_received(:sleep)
    end

    it 'logs warning when waiting' do
      5.times { rate_limiter.record! }
      allow(rate_limiter).to receive(:sleep)

      expect(Rails.logger).to receive(:warn).with(/Rate limit reached/)

      rate_limiter.wait_if_needed
    end
  end

  describe 'integration with cache expiration' do
    it 'resets count after expiration', :skip_in_ci do
      # Use a short period for testing
      short_limiter = described_class.new(key: 'short_test', limit: 2, period: 1)

      2.times { short_limiter.record! }
      expect(short_limiter.allowed?).to be false

      # Wait for cache to expire
      sleep(1.1)

      expect(short_limiter.allowed?).to be true
      expect(short_limiter.current_count).to eq(0)
    end
  end

  describe 'multiple rate limiters' do
    it 'maintains separate counts for different keys' do
      limiter1 = described_class.new(key: 'api1', limit: 5, period: 60)
      limiter2 = described_class.new(key: 'api2', limit: 5, period: 60)

      3.times { limiter1.record! }
      2.times { limiter2.record! }

      expect(limiter1.current_count).to eq(3)
      expect(limiter2.current_count).to eq(2)
    end
  end
end
