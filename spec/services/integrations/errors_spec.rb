require 'rails_helper'

RSpec.describe 'Integrations::Errors', type: :service do
  describe 'Error class hierarchy' do
    it 'defines base Error class' do
      expect(Integrations::Error).to be < StandardError
    end

    it 'defines OAuth errors' do
      expect(Integrations::OAuthError).to be < Integrations::Error
      expect(Integrations::AuthenticationError).to be < Integrations::Error
      expect(Integrations::AuthorizationError).to be < Integrations::Error
      expect(Integrations::UnauthorizedError).to be < Integrations::Error
      expect(Integrations::ForbiddenError).to be < Integrations::Error
    end

    it 'defines API errors' do
      expect(Integrations::APIError).to be < Integrations::Error
      expect(Integrations::NotFoundError).to be < Integrations::APIError
      expect(Integrations::RateLimitError).to be < Integrations::APIError
      expect(Integrations::ServerError).to be < Integrations::APIError
      expect(Integrations::TimeoutError).to be < Integrations::APIError
    end

    it 'defines rate limiter errors' do
      expect(Integrations::RateLimitExceededError).to be < Integrations::Error
    end
  end

  describe 'Error raising and handling' do
    it 'can raise and catch base Error' do
      expect {
        raise Integrations::Error, 'Test error'
      }.to raise_error(Integrations::Error, 'Test error')
    end

    it 'can raise and catch OAuthError' do
      expect {
        raise Integrations::OAuthError, 'OAuth failed'
      }.to raise_error(Integrations::OAuthError, 'OAuth failed')
    end

    it 'can raise and catch APIError' do
      expect {
        raise Integrations::APIError, 'API request failed'
      }.to raise_error(Integrations::APIError, 'API request failed')
    end

    it 'can raise and catch RateLimitError' do
      expect {
        raise Integrations::RateLimitError, 'Too many requests'
      }.to raise_error(Integrations::RateLimitError, 'Too many requests')
    end

    it 'catches specific errors with base Error' do
      expect {
        raise Integrations::NotFoundError, 'Resource not found'
      }.to raise_error(Integrations::Error)
    end

    it 'catches API errors with APIError' do
      expect {
        raise Integrations::ServerError, 'Server error'
      }.to raise_error(Integrations::APIError)
    end
  end
end
