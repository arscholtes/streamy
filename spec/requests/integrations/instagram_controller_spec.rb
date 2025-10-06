require 'rails_helper'

RSpec.describe Integrations::InstagramController, type: :request do
  let(:user) { create(:user) }
  let(:instagram_account) { create(:instagram_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/instagram/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/instagram/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Instagram integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/instagram/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/instagram/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/instagram/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Instagram connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/instagram/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Instagram authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/instagram/disconnect' do
    context 'when Instagram account exists' do
      before { instagram_account }

      it 'destroys the Instagram account' do
        expect {
          delete '/integrations/instagram/disconnect'
        }.to change(InstagramAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/instagram/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Instagram account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/instagram/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/instagram/sync' do
    context 'when Instagram account exists' do
      before { instagram_account }

      it 'redirects to settings with success message' do
        post '/integrations/instagram/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Instagram sync started')
      end
    end

    context 'when Instagram account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/instagram/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Instagram account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/instagram/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
