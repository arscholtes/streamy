require 'rails_helper'

RSpec.describe Integrations::OpenaiController, type: :request do
  let(:user) { create(:user) }
  let(:openai_integration) { create(:openai_integration, user: user, api_key: 'sk-test123', organization_id: 'org-test') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/openai/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/openai/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('OpenAI integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/openai/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/openai/create' do
    context 'with valid API key' do
      let(:api_key) { 'sk-test-api-key-123' }
      let(:organization_id) { 'org-test-456' }

      it 'creates a new OpenAI integration' do
        expect {
          post '/integrations/openai/create', params: { api_key: api_key, organization_id: organization_id }
        }.to change(OpenaiIntegration, :count).by(1)
      end

      it 'stores API key and organization ID correctly' do
        post '/integrations/openai/create', params: { api_key: api_key, organization_id: organization_id }
        integration = user.reload.openai_integration
        expect(integration.api_key).to eq(api_key)
        expect(integration.organization_id).to eq(organization_id)
        expect(integration.usage_limit).to eq(1000)
        expect(integration.usage_count).to eq(0)
      end

      it 'updates existing OpenAI integration' do
        openai_integration # Create existing integration
        new_api_key = 'sk-new-key-789'

        expect {
          post '/integrations/openai/create', params: { api_key: new_api_key, organization_id: organization_id }
        }.not_to change(OpenaiIntegration, :count)

        integration = user.reload.openai_integration
        expect(integration.api_key).to eq(new_api_key)
      end

      it 'redirects to settings with success message' do
        post '/integrations/openai/create', params: { api_key: api_key, organization_id: organization_id }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('OpenAI API key configured successfully')
      end
    end

    context 'without API key' do
      it 'redirects to settings with error message' do
        post '/integrations/openai/create', params: { api_key: '', organization_id: 'org-test' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('API key is required')
      end

      it 'does not create an integration' do
        expect {
          post '/integrations/openai/create', params: { api_key: '', organization_id: 'org-test' }
        }.not_to change(OpenaiIntegration, :count)
      end
    end

    context 'when save fails' do
      before do
        allow_any_instance_of(OpenaiIntegration).to receive(:update!).and_raise(StandardError.new('Database error'))
      end

      it 'redirects to settings with error message' do
        post '/integrations/openai/create', params: { api_key: 'sk-test', organization_id: 'org-test' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Failed to configure OpenAI API')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/openai/create', params: { api_key: 'sk-test', organization_id: 'org-test' }
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'DELETE /integrations/openai/disconnect' do
    context 'when OpenAI integration exists' do
      before { openai_integration }

      it 'destroys the OpenAI integration' do
        expect {
          delete '/integrations/openai/disconnect'
        }.to change(OpenaiIntegration, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/openai/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('OpenAI integration disconnected')
      end
    end

    context 'when OpenAI integration does not exist' do
      it 'does not raise error' do
        expect {
          delete '/integrations/openai/disconnect'
        }.not_to raise_error
      end

      it 'redirects to settings' do
        delete '/integrations/openai/disconnect'
        expect(response).to redirect_to(settings_path)
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/openai/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
