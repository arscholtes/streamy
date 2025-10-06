require 'rails_helper'

RSpec.describe Integrations::TiktokController, type: :request do
  let(:user) { create(:user) }
  let(:tiktok_account) { create(:tiktok_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/tiktok/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/tiktok/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('TikTok integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/tiktok/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/tiktok/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/tiktok/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('TikTok connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/tiktok/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('TikTok authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/tiktok/disconnect' do
    context 'when TikTok account exists' do
      before { tiktok_account }

      it 'destroys the TikTok account' do
        expect {
          delete '/integrations/tiktok/disconnect'
        }.to change(TiktokAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/tiktok/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('TikTok account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/tiktok/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/tiktok/sync' do
    context 'when TikTok account exists' do
      before { tiktok_account }

      it 'redirects to settings with success message' do
        post '/integrations/tiktok/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('TikTok sync started')
      end
    end

    context 'when TikTok account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/tiktok/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No TikTok account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/tiktok/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
