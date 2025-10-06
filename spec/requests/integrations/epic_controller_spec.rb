require 'rails_helper'

RSpec.describe Integrations::EpicController, type: :request do
  let(:user) { create(:user) }
  let(:epic_account) { create(:epic_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/epic/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/epic/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Epic Games integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/epic/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/epic/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/epic/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Epic Games connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/epic/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('Epic Games authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/epic/disconnect' do
    context 'when Epic account exists' do
      before { epic_account }

      it 'destroys the Epic account' do
        expect {
          delete '/integrations/epic/disconnect'
        }.to change(EpicAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/epic/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Epic Games account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/epic/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/epic/sync' do
    context 'when Epic account exists' do
      before { epic_account }

      it 'redirects to settings with success message' do
        post '/integrations/epic/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('Epic Games sync started')
      end
    end

    context 'when Epic account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/epic/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No Epic Games account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/epic/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
