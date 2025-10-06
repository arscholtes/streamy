require 'rails_helper'

RSpec.describe Integrations::PaypalController, type: :request do
  let(:user) { create(:user) }
  let(:paypal_account) { create(:paypal_account, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end

  describe 'GET /integrations/paypal/connect' do
    context 'when user is logged in' do
      it 'shows coming soon message' do
        get '/integrations/paypal/connect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('PayPal integration coming soon')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        get '/integrations/paypal/connect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /integrations/paypal/callback' do
    context 'with authorization code' do
      it 'shows success message' do
        get '/integrations/paypal/callback', params: { code: 'auth_code_123' }
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('PayPal connected successfully')
      end
    end

    context 'without authorization code' do
      it 'redirects to settings with error message' do
        get '/integrations/paypal/callback'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('PayPal authorization failed')
      end
    end
  end

  describe 'DELETE /integrations/paypal/disconnect' do
    context 'when PayPal account exists' do
      before { paypal_account }

      it 'destroys the PayPal account' do
        expect {
          delete '/integrations/paypal/disconnect'
        }.to change(PaypalAccount, :count).by(-1)
      end

      it 'redirects to settings with success message' do
        delete '/integrations/paypal/disconnect'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('PayPal account disconnected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        delete '/integrations/paypal/disconnect'
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST /integrations/paypal/sync' do
    context 'when PayPal account exists' do
      before { paypal_account }

      it 'redirects to settings with success message' do
        post '/integrations/paypal/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:success]).to eq('PayPal sync started')
      end
    end

    context 'when PayPal account does not exist' do
      it 'redirects to settings with error message' do
        post '/integrations/paypal/sync'
        expect(response).to redirect_to(settings_path)
        expect(flash[:error]).to eq('No PayPal account connected')
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:require_login).and_call_original
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'requires login' do
        post '/integrations/paypal/sync'
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
