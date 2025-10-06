require 'rails_helper'

RSpec.describe DonationsController, type: :request do
  let(:user) { create(:user) }
  let(:streamer) { create(:user, username: 'streamer1') }
  let(:stripe_account) { create(:stripe_account, user: streamer, charges_enabled: true, stripe_id: 'acct_123') }

  before do
    # Login helper for tests
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
  end

  describe 'GET /users/:username/donate' do
    it 'shows donation page when logged in' do
      get new_user_donation_path(username: streamer.username)

      expect(response).to have_http_status(:success)
      expect(assigns(:streamer)).to eq(streamer)
      expect(assigns(:amounts)).to eq([500, 1000, 2000, 5000, 10000])
    end

    it 'requires login' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)

      get new_user_donation_path(username: streamer.username)

      expect(response).to redirect_to(login_path)
    end

    it 'handles non-existent streamer' do
      get new_user_donation_path(username: 'nonexistent')

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq('Streamer not found')
    end
  end

  describe 'POST /users/:username/donate' do
    before do
      stripe_account # Create the stripe account
    end

    it 'creates donation checkout session for valid amount' do
      session_double = double('Stripe::Checkout::Session', url: 'https://checkout.stripe.com/session123')
      allow(Stripe::Checkout::Session).to receive(:create).and_return(session_double)

      post user_donations_path(username: streamer.username), params: {
        amount_cents: 1000,
        message: 'Great stream!'
      }

      expect(response).to redirect_to('https://checkout.stripe.com/session123')
    end

    it 'rejects amounts below minimum' do
      post user_donations_path(username: streamer.username), params: {
        amount_cents: 50
      }

      expect(response).to redirect_to(new_user_donation_path(streamer.username))
      expect(flash[:error]).to eq('Minimum donation amount is $1.00')
    end

    it 'rejects when streamer has no Stripe account' do
      streamer_without_stripe = create(:user, username: 'nostripe')

      post user_donations_path(username: streamer_without_stripe.username), params: {
        amount_cents: 1000
      }

      expect(response).to redirect_to(user_path(streamer_without_stripe))
      expect(flash[:error]).to eq("This streamer hasn't set up donations yet")
    end

    it 'rejects when streamer Stripe account is not charges_enabled' do
      disabled_account = create(:stripe_account, user: streamer, charges_enabled: false)
      streamer.update(stripe_account: disabled_account)

      post user_donations_path(username: streamer.username), params: {
        amount_cents: 1000
      }

      expect(response).to redirect_to(user_path(streamer))
      expect(flash[:error]).to eq("This streamer hasn't set up donations yet")
    end

    it 'handles Stripe errors gracefully' do
      allow(Stripe::Checkout::Session).to receive(:create).and_raise(Stripe::StripeError.new('API error'))

      post user_donations_path(username: streamer.username), params: {
        amount_cents: 1000,
        message: 'Great stream!'
      }

      expect(response).to redirect_to(new_user_donation_path(streamer.username))
      expect(flash[:error]).to eq('Failed to process donation. Please try again.')
    end

    it 'includes message in metadata' do
      session_double = double('Stripe::Checkout::Session', url: 'https://checkout.stripe.com/session123')
      expect(Stripe::Checkout::Session).to receive(:create) do |args|
        expect(args[:payment_intent_data][:metadata][:message]).to eq('Thanks!')
        session_double
      end

      post user_donations_path(username: streamer.username), params: {
        amount_cents: 2000,
        message: 'Thanks!'
      }
    end
  end

  describe 'GET /users/:username/donate/success' do
    it 'shows success message' do
      get donation_success_path(username: streamer.username)

      expect(response).to redirect_to(user_path(streamer))
      expect(flash[:success]).to include("Thank you for your donation to #{streamer.username}")
    end

    it 'handles non-existent streamer' do
      expect {
        get donation_success_path(username: 'nonexistent')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /donations' do
    let!(:sent_payment) { create(:payment, user: user, recipient: streamer, payment_type: 'donation', amount_cents: 1000) }
    let!(:received_payment) { create(:payment, user: streamer, recipient: user, payment_type: 'tip', amount_cents: 500) }

    it 'shows sent and received donations' do
      get donations_path

      expect(response).to have_http_status(:success)
      expect(assigns(:sent_donations)).to include(sent_payment)
      expect(assigns(:received_donations)).to include(received_payment)
    end

    it 'filters by donation and tip payment types' do
      other_payment = create(:payment, user: user, recipient: streamer, payment_type: 'other')

      get donations_path

      expect(assigns(:sent_donations)).not_to include(other_payment)
    end

    it 'orders by created_at desc' do
      older_payment = create(:payment, user: user, recipient: streamer, payment_type: 'donation', created_at: 1.day.ago)
      newer_payment = create(:payment, user: user, recipient: streamer, payment_type: 'donation', created_at: 1.hour.ago)

      get donations_path

      donations = assigns(:sent_donations).to_a
      expect(donations.first).to eq(newer_payment)
    end
  end
end
