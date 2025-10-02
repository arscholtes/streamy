# app/services/integrations/rate_limiter.rb
# Token bucket rate limiter using Redis
# Prevents API rate limit violations by tracking and throttling requests

module Integrations
  class RateLimiter
    attr_reader :requests_per_second, :burst, :key_prefix

    def initialize(config)
      @requests_per_second = config[:requests_per_second] || 10
      @burst = config[:burst] || 50
      @key_prefix = config[:key_prefix] || 'rate_limit'
      @redis = Redis.new
    end

    # Wait if necessary to stay within rate limits
    # Uses token bucket algorithm
    def wait_if_needed
      loop do
        if can_make_request?
          consume_token
          break
        else
          sleep(sleep_duration)
        end
      end
    end

    # Check if request can be made without blocking
    # @return [Boolean]
    def can_make_request?
      current_tokens >= 1
    end

    private

    # Get current number of available tokens
    def current_tokens
      now = Time.current.to_f
      last_update = last_update_time

      # Calculate tokens to add since last update
      time_passed = now - last_update
      tokens_to_add = time_passed * requests_per_second

      # Get current token count
      current = @redis.get(tokens_key).to_f

      # Add new tokens, capped at burst
      new_tokens = [current + tokens_to_add, burst.to_f].min

      # Update Redis
      @redis.set(tokens_key, new_tokens)
      @redis.set(last_update_key, now)

      new_tokens
    end

    # Consume one token
    def consume_token
      @redis.decrbyfloat(tokens_key, 1.0)
    end

    # Get last update timestamp
    def last_update_time
      @redis.get(last_update_key).to_f || Time.current.to_f
    end

    # Calculate how long to sleep
    def sleep_duration
      1.0 / requests_per_second
    end

    # Redis keys
    def tokens_key
      "#{key_prefix}:tokens"
    end

    def last_update_key
      "#{key_prefix}:last_update"
    end
  end
end
