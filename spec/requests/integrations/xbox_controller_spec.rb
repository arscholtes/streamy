require 'rails_helper'

RSpec.describe Integrations::XboxController, type: :request do
  let(:user) { create(:user) }
  let(:xbox_account) { create(:xbox_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/xbox/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/xbox/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Xbox Live integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/xbox/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/xbox/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/xbox/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Xbox Live connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/xbox/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Xbox Live authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/xbox/disconnect' do
    context 'when Xbox account exists' do
      before { xbox_account }

      it 'destroys the Xbox account' do
        expect {
          delete '/integrations/xbox/disconnect'
        }.to change(XboxAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/xbox/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Xbox Live account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/xbox/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/xbox/sync' do
    context 'when Xbox account exists' do
      before { xbox_account }

      it 'redirects to settings with success message' do
        post '/integrations/xbox/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Xbox Live sync started')
      end
    end

    context 'when Xbox account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/xbox/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Xbox Live account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/xbox/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
