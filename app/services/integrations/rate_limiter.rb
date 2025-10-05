module Integrations
  class RateLimiter
    attr_reader :key, :limit, :period

    def initialize(key:, limit:, period: 60)
      @key = "rate_limit:#{key}"
      @limit = limit
      @period = period
    end

    # Check if request is allowed
    def allowed?
      current_count < limit
    end

    # Increment counter and check if allowed
    def check!
      return true if allowed?

      wait_time = time_until_reset
      raise RateLimitExceededError, "Rate limit exceeded. Try again in #{wait_time} seconds"
    end

    # Wait if needed before making request
    def wait_if_needed
      return if allowed?

      wait_time = time_until_reset
      Rails.logger.warn("Rate limit reached for #{key}. Waiting #{wait_time} seconds...")
      sleep(wait_time)
    end

    # Record a request
    def record!
      increment_counter
    end

    # Get current request count
    def current_count
      Rails.cache.read(key) || 0
    end

    # Time until rate limit resets
    def time_until_reset
      ttl = Rails.cache.read("#{key}:ttl")
      return 0 unless ttl

      (ttl - Time.current).to_i.clamp(0, period)
    end

    private

    def increment_counter
      count = current_count
      new_count = count + 1

      if count == 0
        # First request in this period - set expiration
        Rails.cache.write(key, new_count, expires_in: period)
        Rails.cache.write("#{key}:ttl", period.seconds.from_now, expires_in: period)
      else
        # Increment existing counter
        Rails.cache.write(key, new_count)
      end

      new_count
    end
  end

  class RateLimitExceededError < StandardError; end
end
