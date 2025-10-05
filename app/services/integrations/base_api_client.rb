require_relative 'errors'

module Integrations
  class BaseApiClient
    include HTTParty

    attr_reader :integration_account, :access_token

    def initialize(integration_account)
      @integration_account = integration_account
      @access_token = integration_account.access_token
      setup_client
    end

    # GET request
    def get(endpoint, params: {})
      make_request(:get, endpoint, query: params)
    end

    # POST request
    def post(endpoint, body: {}, params: {})
      make_request(:post, endpoint, body: body, query: params)
    end

    # PUT request
    def put(endpoint, body: {}, params: {})
      make_request(:put, endpoint, body: body, query: params)
    end

    # DELETE request
    def delete(endpoint, params: {})
      make_request(:delete, endpoint, query: params)
    end

    protected

    # Override in subclass to set base_uri, etc.
    def setup_client
      # Example:
      # self.class.base_uri 'https://api.example.com'
      # self.class.headers 'User-Agent' => 'StreamHub/1.0'
    end

    # Override to customize API endpoint URL
    def api_base_url
      raise NotImplementedError, "#{self.class} must define api_base_url"
    end

    # Default headers for all requests
    def default_headers
      {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    end

    # Make HTTP request with error handling
    def make_request(method, endpoint, options = {})
      # Ensure token is valid before making request
      integration_account.ensure_valid_token!

      # Build full URL
      url = build_url(endpoint)

      # Merge headers
      options[:headers] = default_headers.merge(options[:headers] || {})

      # Convert body to JSON if present
      options[:body] = options[:body].to_json if options[:body] && !options[:body].is_a?(String)

      # Make request
      response = self.class.send(method, url, options)

      handle_response(response)
    rescue StandardError => e
      handle_error(e)
    end

    def build_url(endpoint)
      endpoint.start_with?('http') ? endpoint : "#{api_base_url}#{endpoint}"
    end

    def handle_response(response)
      case response.code
      when 200..299
        parse_response(response)
      when 401
        raise UnauthorizedError, "Invalid or expired access token"
      when 403
        raise ForbiddenError, "Access forbidden"
      when 404
        raise NotFoundError, "Resource not found"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 500..599
        raise ServerError, "Server error: #{response.code}"
      else
        raise APIError, "Request failed with status #{response.code}: #{response.body}"
      end
    end

    def parse_response(response)
      return nil if response.body.blank?

      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError
      response.body
    end

    def handle_error(error)
      Rails.logger.error("API request failed: #{error.class} - #{error.message}")
      raise error
    end
  end

  # Custom exceptions
  class APIError < StandardError; end
  class UnauthorizedError < APIError; end
  class ForbiddenError < APIError; end
  class NotFoundError < APIError; end
  class RateLimitError < APIError; end
  class ServerError < APIError; end
end
