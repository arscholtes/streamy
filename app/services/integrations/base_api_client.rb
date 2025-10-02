# app/services/integrations/base_api_client.rb
# Base API client for making authenticated requests to external APIs
# Includes rate limiting, error handling, and automatic token refresh

module Integrations
  class BaseApiClient
    include HTTParty

    attr_reader :access_token, :integration_account

    def initialize(integration_account)
      @integration_account = integration_account
      @access_token = integration_account.access_token
      @rate_limiter = RateLimiter.new(rate_limit_config)
    end

    # Make GET request
    # @param endpoint [String] API endpoint path
    # @param params [Hash] Query parameters
    # @return [Hash] Parsed JSON response
    def get(endpoint, params: {})
      make_request(:get, endpoint, params: params)
    end

    # Make POST request
    # @param endpoint [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] Parsed JSON response
    def post(endpoint, body: {})
      make_request(:post, endpoint, body: body)
    end

    # Make PUT request
    # @param endpoint [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] Parsed JSON response
    def put(endpoint, body: {})
      make_request(:put, endpoint, body: body)
    end

    # Make DELETE request
    # @param endpoint [String] API endpoint path
    # @return [Hash] Parsed JSON response
    def delete(endpoint)
      make_request(:delete, endpoint)
    end

    private

    # Make HTTP request with rate limiting, auth, and error handling
    def make_request(method, endpoint, params: {}, body: {}, retry_count: 0)
      # Wait if rate limited
      @rate_limiter.wait_if_needed

      # Ensure token is valid
      integration_account.ensure_valid_token!

      # Make request
      response = self.class.send(
        method,
        build_url(endpoint),
        headers: default_headers,
        query: params,
        body: body.to_json
      )

      handle_response(response)
    rescue RateLimitError => e
      # Exponential backoff for rate limits
      if retry_count < 3
        sleep_time = 2 ** retry_count
        Rails.logger.warn("Rate limited, retrying in #{sleep_time}s...")
        sleep(sleep_time)
        make_request(method, endpoint, params: params, body: body, retry_count: retry_count + 1)
      else
        raise e
      end
    rescue TokenExpiredError => e
      # Token refresh failed, need re-authentication
      raise APIError, "Token expired and refresh failed. Re-authentication required."
    end

    # Build full URL from endpoint
    def build_url(endpoint)
      "#{base_url}#{endpoint}"
    end

    # Default request headers
    def default_headers
      {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'User-Agent' => 'StreamHub/1.0'
      }
    end

    # Handle API response
    def handle_response(response)
      case response.code
      when 200..299
        # Success
        parse_response(response)
      when 429
        # Rate limited
        retry_after = response.headers['Retry-After']&.to_i || 60
        Rails.logger.warn("Rate limited by API, retry after #{retry_after}s")
        raise RateLimitError.new("Rate limited", retry_after: retry_after)
      when 401
        # Unauthorized - token might be expired
        Rails.logger.warn("Unauthorized response, attempting token refresh")
        if integration_account.refresh_token!
          @access_token = integration_account.access_token
          raise TokenExpiredError, "Token refreshed, retry request"
        else
          raise APIError, "Authentication failed"
        end
      when 403
        # Forbidden
        raise APIError, "Access forbidden: #{response.body}"
      when 404
        # Not found
        raise APIError, "Resource not found: #{response.code}"
      when 500..599
        # Server error
        raise APIError, "Server error (#{response.code}): #{response.body}"
      else
        raise APIError, "Unexpected response (#{response.code}): #{response.body}"
      end
    end

    # Parse JSON response
    def parse_response(response)
      return {} if response.body.blank?
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error("JSON parse error: #{e.message}")
      raise APIError, "Invalid JSON response"
    end

    # Override in subclasses to specify base URL
    def base_url
      raise NotImplementedError, "#{self.class.name} must implement #base_url"
    end

    # Override in subclasses to configure rate limits
    # @return [Hash] Rate limit configuration
    def rate_limit_config
      {
        requests_per_second: 10,
        burst: 50,
        key_prefix: self.class.name.demodulize.underscore
      }
    end
  end

  # Custom errors
  class APIError < StandardError; end

  class RateLimitError < StandardError
    attr_reader :retry_after

    def initialize(message, retry_after: 60)
      super(message)
      @retry_after = retry_after
    end
  end

  class TokenExpiredError < StandardError; end
end
