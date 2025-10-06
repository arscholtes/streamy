require 'rails_helper'

RSpec.describe Integrations::GoogleAnalyticsController, type: :request do
  let(:user) { create(:user) }
  let(:google_analytics_account) { create(:google_analytics_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/google_analytics/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/google_analytics/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Google Analytics integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/google_analytics/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/google_analytics/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/google_analytics/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Google Analytics connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/google_analytics/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Google Analytics authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/google_analytics/disconnect' do
    context 'when Google Analytics account exists' do
      before { google_analytics_account }

      it 'destroys the Google Analytics account' do
        expect {
          delete '/integrations/google_analytics/disconnect'
        }.to change(GoogleAnalyticsAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/google_analytics/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Google Analytics account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/google_analytics/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/google_analytics/sync' do
    context 'when Google Analytics account exists' do
      before { google_analytics_account }

      it 'redirects to settings with success message' do
        post '/integrations/google_analytics/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Google Analytics sync started')
      end
    end

    context 'when Google Analytics account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/google_analytics/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Google Analytics account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/google_analytics/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
