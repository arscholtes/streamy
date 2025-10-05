# app/services/integrations/errors.rb
# Custom error classes for integrations
module Integrations
  # Base error class for all integration errors
  class Error < StandardError; end

  # OAuth and authentication errors
  class OAuthError < Error; end
  class AuthenticationError < Error; end
  class AuthorizationError < Error; end
  class UnauthorizedError < Error; end
  class ForbiddenError < Error; end

  # API errors
  class APIError < Error; end
  class NotFoundError < APIError; end
  class RateLimitError < APIError; end
  class ServerError < APIError; end
  class TimeoutError < APIError; end

  # Rate limiter errors
  class RateLimitExceededError < Error; end
end
