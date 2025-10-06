require 'rails_helper'

RSpec.describe Integrations::TwitchController, type: :request do
  let(:user) { create(:user) }
  let(:twitch_account) { create(:twitch_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/twitch/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/twitch/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Twitch integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/twitch/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/twitch/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/twitch/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Twitch connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/twitch/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Twitch authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/twitch/disconnect' do
    context 'when Twitch account exists' do
      before { twitch_account }

      it 'destroys the Twitch account' do
        expect {
          delete '/integrations/twitch/disconnect'
        }.to change(TwitchAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/twitch/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Twitch account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/twitch/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/twitch/sync' do
    context 'when Twitch account exists' do
      before { twitch_account }

      it 'redirects to settings with success message' do
        post '/integrations/twitch/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Twitch sync started')
      end
    end

    context 'when Twitch account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/twitch/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Twitch account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/twitch/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
