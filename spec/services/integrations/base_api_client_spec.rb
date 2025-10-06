require 'rails_helper'

RSpec.describe Integrations::BaseApiClient, type: :service do
  # Create a test integration account model
  let(:integration_account) do
    double('IntegrationAccount',
      access_token: 'test_access_token',
      ensure_valid_token!: true
    )
  end

  # Create a test subclass for testing the base class
  let(:test_client_class) do
    Class.new(Integrations::BaseApiClient) do
      def api_base_url
        'https://api.example.com'
      end
    end
  end

  let(:client) { test_client_class.new(integration_account) }

  describe '#initialize' do
    it 'sets the integration account' do
      expect(client.integration_account).to eq(integration_account)
    end

    it 'sets the access token' do
      expect(client.access_token).to eq('test_access_token')
    end

    it 'calls setup_client' do
      expect_any_instance_of(test_client_class).to receive(:setup_client)
      test_client_class.new(integration_account)
    end
  end

  describe '#get' do
    let(:response_body) { { data: 'test' }.to_json }

    before do
      allow(integration_account).to receive(:ensure_valid_token!).and_return(true)
    end

    it 'makes GET request to API endpoint' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 200, body: response_body)

      result = client.get('/test')
      expect(result[:data]).to eq('test')
    end

    it 'includes authorization header' do
      stub_request(:get, 'https://api.example.com/test')
        .with(headers: { 'Authorization' => 'Bearer test_access_token' })
        .to_return(status: 200, body: response_body)

      client.get('/test')
    end

    it 'includes query parameters' do
      stub_request(:get, 'https://api.example.com/test')
        .with(query: { foo: 'bar', baz: 'qux' })
        .to_return(status: 200, body: response_body)

      client.get('/test', params: { foo: 'bar', baz: 'qux' })
    end

    it 'ensures token is valid before request' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 200, body: response_body)

      expect(integration_account).to receive(:ensure_valid_token!)

      client.get('/test')
    end
  end

  describe '#post' do
    let(:response_body) { { created: true }.to_json }

    before do
      allow(integration_account).to receive(:ensure_valid_token!).and_return(true)
    end

    it 'makes POST request to API endpoint' do
      stub_request(:post, 'https://api.example.com/test')
        .to_return(status: 200, body: response_body)

      result = client.post('/test')
      expect(result[:created]).to be true
    end

    it 'includes request body as JSON' do
      stub_request(:post, 'https://api.example.com/test')
        .with(body: { name: 'Test', value: 123 }.to_json)
        .to_return(status: 200, body: response_body)

      client.post('/test', body: { name: 'Test', value: 123 })
    end

    it 'includes Content-Type header' do
      stub_request(:post, 'https://api.example.com/test')
        .with(headers: { 'Content-Type' => 'application/json' })
        .to_return(status: 200, body: response_body)

      client.post('/test', body: { data: 'test' })
    end
  end

  describe '#put' do
    let(:response_body) { { updated: true }.to_json }

    before do
      allow(integration_account).to receive(:ensure_valid_token!).and_return(true)
    end

    it 'makes PUT request to API endpoint' do
      stub_request(:put, 'https://api.example.com/test/1')
        .to_return(status: 200, body: response_body)

      result = client.put('/test/1')
      expect(result[:updated]).to be true
    end

    it 'includes request body' do
      stub_request(:put, 'https://api.example.com/test/1')
        .with(body: { name: 'Updated' }.to_json)
        .to_return(status: 200, body: response_body)

      client.put('/test/1', body: { name: 'Updated' })
    end
  end

  describe '#delete' do
    before do
      allow(integration_account).to receive(:ensure_valid_token!).and_return(true)
    end

    it 'makes DELETE request to API endpoint' do
      stub_request(:delete, 'https://api.example.com/test/1')
        .to_return(status: 204, body: '')

      client.delete('/test/1')
    end

    it 'includes query parameters' do
      stub_request(:delete, 'https://api.example.com/test/1')
        .with(query: { confirm: 'true' })
        .to_return(status: 204, body: '')

      client.delete('/test/1', params: { confirm: 'true' })
    end
  end

  describe '#build_url' do
    it 'builds URL with api_base_url for relative endpoints' do
      url = client.send(:build_url, '/test')
      expect(url).to eq('https://api.example.com/test')
    end

    it 'uses absolute URL as-is' do
      url = client.send(:build_url, 'https://other-api.com/test')
      expect(url).to eq('https://other-api.com/test')
    end
  end

  describe '#default_headers' do
    it 'includes authorization header' do
      headers = client.send(:default_headers)
      expect(headers['Authorization']).to eq('Bearer test_access_token')
    end

    it 'includes content-type header' do
      headers = client.send(:default_headers)
      expect(headers['Content-Type']).to eq('application/json')
    end

    it 'includes accept header' do
      headers = client.send(:default_headers)
      expect(headers['Accept']).to eq('application/json')
    end
  end

  describe 'error handling' do
    before do
      allow(integration_account).to receive(:ensure_valid_token!).and_return(true)
    end

    it 'raises UnauthorizedError for 401 status' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 401, body: 'Unauthorized')

      expect {
        client.get('/test')
      }.to raise_error(Integrations::UnauthorizedError, /Invalid or expired access token/)
    end

    it 'raises ForbiddenError for 403 status' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 403, body: 'Forbidden')

      expect {
        client.get('/test')
      }.to raise_error(Integrations::ForbiddenError, /Access forbidden/)
    end

    it 'raises NotFoundError for 404 status' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 404, body: 'Not Found')

      expect {
        client.get('/test')
      }.to raise_error(Integrations::NotFoundError, /Resource not found/)
    end

    it 'raises RateLimitError for 429 status' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 429, body: 'Too Many Requests')

      expect {
        client.get('/test')
      }.to raise_error(Integrations::RateLimitError, /Rate limit exceeded/)
    end

    it 'raises ServerError for 500 status' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 500, body: 'Internal Server Error')

      expect {
        client.get('/test')
      }.to raise_error(Integrations::ServerError, /Server error: 500/)
    end

    it 'raises ServerError for 503 status' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 503, body: 'Service Unavailable')

      expect {
        client.get('/test')
      }.to raise_error(Integrations::ServerError, /Server error: 503/)
    end

    it 'raises APIError for other error statuses' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 418, body: "I'm a teapot")

      expect {
        client.get('/test')
      }.to raise_error(Integrations::APIError, /Request failed with status 418/)
    end

    it 'logs errors' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 500, body: 'Error')

      expect(Rails.logger).to receive(:error).with(/API request failed/)

      expect {
        client.get('/test')
      }.to raise_error(Integrations::ServerError)
    end
  end

  describe '#parse_response' do
    before do
      allow(integration_account).to receive(:ensure_valid_token!).and_return(true)
    end

    it 'parses JSON response with symbolized keys' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 200, body: { name: 'Test', value: 123 }.to_json)

      result = client.get('/test')
      expect(result[:name]).to eq('Test')
      expect(result[:value]).to eq(123)
    end

    it 'returns nil for empty response' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 200, body: '')

      result = client.get('/test')
      expect(result).to be_nil
    end

    it 'returns raw body if JSON parsing fails' do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 200, body: 'Not JSON')

      result = client.get('/test')
      expect(result).to eq('Not JSON')
    end
  end

  describe '#api_base_url' do
    it 'raises NotImplementedError if not overridden' do
      base_client_class = Class.new(Integrations::BaseApiClient)

      expect {
        base_client_class.new(integration_account).send(:api_base_url)
      }.to raise_error(NotImplementedError, /must define api_base_url/)
    end
  end
end
