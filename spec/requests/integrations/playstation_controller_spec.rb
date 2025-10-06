require 'rails_helper'

RSpec.describe Integrations::PlaystationController, type: :request do
  let(:user) { create(:user) }
  let(:playstation_account) { create(:playstation_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/playstation/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/playstation/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('PlayStation Network integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/playstation/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/playstation/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/playstation/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('PlayStation Network connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/playstation/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('PlayStation Network authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/playstation/disconnect' do
    context 'when PlayStation account exists' do
      before { playstation_account }

      it 'destroys the PlayStation account' do
        expect {
          delete '/integrations/playstation/disconnect'
        }.to change(PlaystationAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/playstation/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('PlayStation Network account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/playstation/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/playstation/sync' do
    context 'when PlayStation account exists' do
      before { playstation_account }

      it 'redirects to settings with success message' do
        post '/integrations/playstation/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('PlayStation Network sync started')
      end
    end

    context 'when PlayStation account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/playstation/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No PlayStation Network account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/playstation/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
