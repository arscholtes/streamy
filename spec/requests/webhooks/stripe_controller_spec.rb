require 'rails_helper'

RSpec.describe 'Webhooks::Stripe', type: :request do
  let(:webhook_secret) { 'whsec_test_secret' }
  let(:user) { create(:user, stripe_customer_id: 'cus_test123') }
  let(:payload) { webhook_payload.to_json }
  let(:timestamp) { Time.current.to_i }

  before do
    # Mock the Stripe webhook secret
    allow(Rails.configuration.stripe).to receive(:[]).with(:webhook_secret).and_return(webhook_secret)
  end

  # Helper method to generate valid Stripe signature
  def generate_stripe_signature(payload, timestamp, secret)
    signed_payload = "#{timestamp}.#{payload}"
    signature = OpenSSL::HMAC.hexdigest('sha256', secret, signed_payload)
    "t=#{timestamp},v1=#{signature}"
  end

  # Helper method to send webhook with proper signature
  def send_webhook(event_data, signature: nil)
    sig = signature || generate_stripe_signature(event_data.to_json, timestamp, webhook_secret)
    post '/webhooks/stripe',
         params: event_data.to_json,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'HTTP_STRIPE_SIGNATURE' => sig
         }
  end

  describe 'POST /webhooks/stripe' do
    context 'with invalid signature' do
      it 'returns 400 bad request' do
        event_data = { type: 'customer.subscription.created' }
        send_webhook(event_data, signature: 'invalid_signature')

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Invalid signature' })
      end

      it 'logs signature verification error' do
        allow(Rails.logger).to receive(:error)
        event_data = { type: 'customer.subscription.created' }
        send_webhook(event_data, signature: 'invalid_signature')

        expect(Rails.logger).to have_received(:error).with(/Webhook signature verification failed/)
      end
    end

    context 'with invalid JSON payload' do
      it 'returns 400 bad request' do
        # Send malformed JSON
        sig = generate_stripe_signature('invalid json{', timestamp, webhook_secret)
        post '/webhooks/stripe',
             params: 'invalid json{',
             headers: {
               'CONTENT_TYPE' => 'application/json',
               'HTTP_STRIPE_SIGNATURE' => sig
             }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Invalid payload' })
      end
    end

    context 'customer.subscription.created event' do
      let(:webhook_payload) do
        {
          id: 'evt_test123',
          object: 'event',
          type: 'customer.subscription.created',
          data: {
            object: {
              id: 'sub_test123',
              object: 'subscription',
              customer: user.stripe_customer_id,
              status: 'active',
              current_period_start: 1.day.ago.to_i,
              current_period_end: 1.month.from_now.to_i,
              cancel_at_period_end: false,
              items: {
                data: [
                  {
                    price: {
                      id: 'price_pro123'
                    }
                  }
                ]
              }
            }
          }
        }
      end

      before do
        # Mock the Stripe price ID for pro plan
        allow(Rails.application.credentials).to receive(:dig)
          .with(:stripe, :pro_price_id)
          .and_return('price_pro123')
      end

      it 'creates a new subscription record' do
        expect {
          send_webhook(webhook_payload)
        }.to change(Subscription, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'received' => true })
      end

      it 'sets correct subscription attributes' do
        send_webhook(webhook_payload)

        subscription = Subscription.last
        expect(subscription.user).to eq(user)
        expect(subscription.stripe_subscription_id).to eq('sub_test123')
        expect(subscription.stripe_customer_id).to eq(user.stripe_customer_id)
        expect(subscription.status).to eq('active')
        expect(subscription.plan).to eq('pro')
        expect(subscription.cancel_at_period_end).to be false
      end

      it 'updates user subscription tier to pro' do
        send_webhook(webhook_payload)

        expect(user.reload.subscription_tier).to eq('pro')
      end

      it 'logs subscription creation' do
        allow(Rails.logger).to receive(:info)
        send_webhook(webhook_payload)

        subscription = Subscription.last
        expect(Rails.logger).to have_received(:info)
          .with("Created subscription #{subscription.id} for user #{user.id}")
      end

      context 'when user does not exist' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'customer.subscription.created',
            data: {
              object: {
                id: 'sub_test123',
                object: 'subscription',
                customer: 'cus_nonexistent',
                status: 'active',
                current_period_start: 1.day.ago.to_i,
                current_period_end: 1.month.from_now.to_i,
                cancel_at_period_end: false,
                items: {
                  data: [
                    {
                      price: {
                        id: 'price_pro123'
                      }
                    }
                  ]
                }
              }
            }
          }
        end

        it 'does not create a subscription' do
          expect {
            send_webhook(webhook_payload)
          }.not_to change(Subscription, :count)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when subscription creation fails' do
        it 'logs the error and returns ok' do
          allow(Rails.logger).to receive(:error)
          allow_any_instance_of(User).to receive_message_chain(:subscriptions, :create!)
            .and_raise(ActiveRecord::RecordInvalid.new)

          send_webhook(webhook_payload)

          expect(Rails.logger).to have_received(:error).with(/Failed to create subscription/)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'customer.subscription.updated event' do
      let!(:subscription) do
        create(:subscription,
               user: user,
               stripe_subscription_id: 'sub_test123',
               stripe_customer_id: user.stripe_customer_id,
               status: 'active',
               plan: 'pro',
               current_period_start: 1.month.ago,
               current_period_end: Time.current,
               cancel_at_period_end: false)
      end

      let(:webhook_payload) do
        {
          id: 'evt_test123',
          object: 'event',
          type: 'customer.subscription.updated',
          data: {
            object: {
              id: 'sub_test123',
              object: 'subscription',
              customer: user.stripe_customer_id,
              status: 'active',
              current_period_start: Time.current.to_i,
              current_period_end: 1.month.from_now.to_i,
              cancel_at_period_end: true,
              items: {
                data: [
                  {
                    price: {
                      id: 'price_pro123'
                    }
                  }
                ]
              }
            }
          }
        }
      end

      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:stripe, :pro_price_id)
          .and_return('price_pro123')
      end

      it 'updates existing subscription' do
        send_webhook(webhook_payload)

        subscription.reload
        expect(subscription.cancel_at_period_end).to be true
        expect(subscription.current_period_end).to be_within(1.second).of(1.month.from_now)
        expect(response).to have_http_status(:ok)
      end

      it 'does not create a new subscription' do
        expect {
          send_webhook(webhook_payload)
        }.not_to change(Subscription, :count)
      end

      it 'logs subscription update' do
        allow(Rails.logger).to receive(:info)
        send_webhook(webhook_payload)

        expect(Rails.logger).to have_received(:info)
          .with("Updated subscription #{subscription.id}, status: active")
      end

      context 'when changing to enterprise plan' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'customer.subscription.updated',
            data: {
              object: {
                id: 'sub_test123',
                object: 'subscription',
                customer: user.stripe_customer_id,
                status: 'active',
                current_period_start: Time.current.to_i,
                current_period_end: 1.month.from_now.to_i,
                cancel_at_period_end: false,
                items: {
                  data: [
                    {
                      price: {
                        id: 'price_enterprise123'
                      }
                    }
                  ]
                }
              }
            }
          }
        end

        before do
          allow(Rails.application.credentials).to receive(:dig)
            .with(:stripe, :enterprise_price_id)
            .and_return('price_enterprise123')
        end

        it 'updates the plan to enterprise' do
          send_webhook(webhook_payload)

          subscription.reload
          expect(subscription.plan).to eq('enterprise')
          expect(user.reload.subscription_tier).to eq('enterprise')
        end
      end

      context 'when subscription does not exist' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'customer.subscription.updated',
            data: {
              object: {
                id: 'sub_nonexistent',
                object: 'subscription',
                customer: user.stripe_customer_id,
                status: 'active',
                current_period_start: Time.current.to_i,
                current_period_end: 1.month.from_now.to_i,
                cancel_at_period_end: false,
                items: {
                  data: [
                    {
                      price: {
                        id: 'price_pro123'
                      }
                    }
                  ]
                }
              }
            }
          }
        end

        it 'does not raise error' do
          expect {
            send_webhook(webhook_payload)
          }.not_to raise_error

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'customer.subscription.deleted event' do
      let!(:subscription) do
        create(:subscription,
               user: user,
               stripe_subscription_id: 'sub_test123',
               stripe_customer_id: user.stripe_customer_id,
               status: 'active',
               plan: 'pro',
               current_period_start: 1.month.ago,
               current_period_end: 1.month.from_now,
               cancel_at_period_end: false)
      end

      let(:webhook_payload) do
        {
          id: 'evt_test123',
          object: 'event',
          type: 'customer.subscription.deleted',
          data: {
            object: {
              id: 'sub_test123',
              object: 'subscription',
              customer: user.stripe_customer_id,
              status: 'canceled'
            }
          }
        }
      end

      it 'marks subscription as canceled' do
        send_webhook(webhook_payload)

        subscription.reload
        expect(subscription.status).to eq('canceled')
        expect(subscription.canceled_at).to be_present
        expect(response).to have_http_status(:ok)
      end

      it 'updates user subscription tier to free' do
        send_webhook(webhook_payload)

        expect(user.reload.subscription_tier).to eq('free')
      end

      it 'does not delete the subscription record' do
        expect {
          send_webhook(webhook_payload)
        }.not_to change(Subscription, :count)
      end

      it 'logs subscription cancellation' do
        allow(Rails.logger).to receive(:info)
        send_webhook(webhook_payload)

        expect(Rails.logger).to have_received(:info)
          .with("Canceled subscription #{subscription.id}")
      end
    end

    context 'invoice.payment_succeeded event' do
      let!(:subscription) do
        create(:subscription,
               user: user,
               stripe_subscription_id: 'sub_test123',
               stripe_customer_id: user.stripe_customer_id,
               status: 'active',
               plan: 'pro')
      end

      let(:webhook_payload) do
        {
          id: 'evt_test123',
          object: 'event',
          type: 'invoice.payment_succeeded',
          data: {
            object: {
              id: 'in_test123',
              object: 'invoice',
              subscription: 'sub_test123',
              payment_intent: 'pi_test123',
              charge: 'ch_test123',
              amount_paid: 1900,
              currency: 'usd',
              status_transitions: {
                paid_at: Time.current.to_i
              }
            }
          }
        }
      end

      it 'creates a payment record' do
        expect {
          send_webhook(webhook_payload)
        }.to change(user.payments, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'sets correct payment attributes' do
        send_webhook(webhook_payload)

        payment = user.payments.last
        expect(payment.stripe_payment_intent_id).to eq('pi_test123')
        expect(payment.stripe_charge_id).to eq('ch_test123')
        expect(payment.amount_cents).to eq(1900)
        expect(payment.currency).to eq('usd')
        expect(payment.payment_type).to eq('subscription')
        expect(payment.status).to eq('succeeded')
        expect(payment.paid_at).to be_present
      end

      it 'includes invoice metadata' do
        send_webhook(webhook_payload)

        payment = user.payments.last
        expect(payment.metadata['invoice_id']).to eq('in_test123')
        expect(payment.metadata['subscription_id']).to eq(subscription.id)
      end

      it 'logs payment recording' do
        allow(Rails.logger).to receive(:info)
        send_webhook(webhook_payload)

        expect(Rails.logger).to have_received(:info)
          .with("Recorded subscription payment for subscription #{subscription.id}")
      end

      context 'when invoice has no subscription' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'invoice.payment_succeeded',
            data: {
              object: {
                id: 'in_test123',
                object: 'invoice',
                subscription: nil,
                amount_paid: 1900,
                currency: 'usd'
              }
            }
          }
        end

        it 'does not create a payment record' do
          expect {
            send_webhook(webhook_payload)
          }.not_to change(user.payments, :count)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when subscription does not exist' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'invoice.payment_succeeded',
            data: {
              object: {
                id: 'in_test123',
                object: 'invoice',
                subscription: 'sub_nonexistent',
                payment_intent: 'pi_test123',
                charge: 'ch_test123',
                amount_paid: 1900,
                currency: 'usd',
                status_transitions: {
                  paid_at: Time.current.to_i
                }
              }
            }
          }
        end

        it 'does not create a payment record' do
          expect {
            send_webhook(webhook_payload)
          }.not_to change(Payment, :count)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'invoice.payment_failed event' do
      let!(:subscription) do
        create(:subscription,
               user: user,
               stripe_subscription_id: 'sub_test123',
               stripe_customer_id: user.stripe_customer_id,
               status: 'active',
               plan: 'pro')
      end

      let(:webhook_payload) do
        {
          id: 'evt_test123',
          object: 'event',
          type: 'invoice.payment_failed',
          data: {
            object: {
              id: 'in_test123',
              object: 'invoice',
              subscription: 'sub_test123',
              amount_due: 1900,
              currency: 'usd',
              attempt_count: 2
            }
          }
        }
      end

      it 'logs payment failure warning' do
        allow(Rails.logger).to receive(:warn)
        send_webhook(webhook_payload)

        expect(Rails.logger).to have_received(:warn)
          .with("Invoice payment failed for subscription #{subscription.id}")
        expect(response).to have_http_status(:ok)
      end

      context 'when subscription does not exist' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'invoice.payment_failed',
            data: {
              object: {
                id: 'in_test123',
                object: 'invoice',
                subscription: 'sub_nonexistent',
                amount_due: 1900
              }
            }
          }
        end

        it 'does not raise error' do
          expect {
            send_webhook(webhook_payload)
          }.not_to raise_error

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'unknown event type' do
      let(:webhook_payload) do
        {
          id: 'evt_test123',
          object: 'event',
          type: 'customer.created',
          data: {
            object: {
              id: 'cus_test123'
            }
          }
        }
      end

      it 'logs the unhandled event type' do
        allow(Rails.logger).to receive(:info)
        send_webhook(webhook_payload)

        expect(Rails.logger).to have_received(:info)
          .with("Unhandled webhook event type: customer.created")
        expect(response).to have_http_status(:ok)
      end

      it 'returns success response' do
        send_webhook(webhook_payload)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'received' => true })
      end
    end

    context 'additional webhook events' do
      describe 'checkout.session.completed' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'checkout.session.completed',
            data: {
              object: {
                id: 'cs_test123',
                object: 'checkout.session',
                mode: 'subscription',
                subscription: 'sub_test123',
                metadata: {
                  user_id: user.id.to_s
                }
              }
            }
          }
        end

        it 'logs checkout completion' do
          allow(Rails.logger).to receive(:info)
          send_webhook(webhook_payload)

          expect(Rails.logger).to have_received(:info)
            .with("Checkout completed for user #{user.id}, subscription: sub_test123")
          expect(response).to have_http_status(:ok)
        end

        context 'when mode is not subscription' do
          let(:webhook_payload) do
            {
              id: 'evt_test123',
              object: 'event',
              type: 'checkout.session.completed',
              data: {
                object: {
                  id: 'cs_test123',
                  object: 'checkout.session',
                  mode: 'payment',
                  metadata: {
                    user_id: user.id.to_s
                  }
                }
              }
            }
          end

          it 'does not log checkout completion' do
            allow(Rails.logger).to receive(:info)
            send_webhook(webhook_payload)

            expect(Rails.logger).not_to have_received(:info)
              .with(/Checkout completed/)
            expect(response).to have_http_status(:ok)
          end
        end
      end

      describe 'payment_intent.succeeded' do
        let(:recipient_user) { create(:user) }
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'payment_intent.succeeded',
            data: {
              object: {
                id: 'pi_test123',
                object: 'payment_intent',
                amount: 1000,
                currency: 'usd',
                latest_charge: 'ch_test123',
                application_fee_amount: 100,
                metadata: {
                  user_id: user.id.to_s,
                  recipient_id: recipient_user.id.to_s,
                  payment_type: 'donation'
                }
              }
            }
          }
        end

        it 'creates a payment record' do
          expect {
            send_webhook(webhook_payload)
          }.to change(user.payments, :count).by(1)

          expect(response).to have_http_status(:ok)
        end

        it 'sets correct payment attributes' do
          send_webhook(webhook_payload)

          payment = user.payments.last
          expect(payment.stripe_payment_intent_id).to eq('pi_test123')
          expect(payment.stripe_charge_id).to eq('ch_test123')
          expect(payment.amount_cents).to eq(1000)
          expect(payment.platform_fee_cents).to eq(100)
          expect(payment.recipient_amount_cents).to eq(900)
          expect(payment.currency).to eq('usd')
          expect(payment.payment_type).to eq('donation')
          expect(payment.status).to eq('succeeded')
          expect(payment.recipient).to eq(recipient_user)
        end

        context 'when user does not exist in metadata' do
          let(:webhook_payload) do
            {
              id: 'evt_test123',
              object: 'event',
              type: 'payment_intent.succeeded',
              data: {
                object: {
                  id: 'pi_test123',
                  amount: 1000,
                  currency: 'usd',
                  metadata: {}
                }
              }
            }
          end

          it 'does not create a payment record' do
            expect {
              send_webhook(webhook_payload)
            }.not_to change(Payment, :count)

            expect(response).to have_http_status(:ok)
          end
        end
      end

      describe 'payment_intent.payment_failed' do
        let(:webhook_payload) do
          {
            id: 'evt_test123',
            object: 'event',
            type: 'payment_intent.payment_failed',
            data: {
              object: {
                id: 'pi_test123',
                object: 'payment_intent',
                amount: 1000,
                currency: 'usd',
                last_payment_error: {
                  message: 'Card declined'
                },
                metadata: {
                  user_id: user.id.to_s,
                  payment_type: 'donation'
                }
              }
            }
          }
        end

        it 'creates a failed payment record' do
          expect {
            send_webhook(webhook_payload)
          }.to change(user.payments, :count).by(1)

          payment = user.payments.last
          expect(payment.status).to eq('failed')
          expect(response).to have_http_status(:ok)
        end

        it 'logs payment failure' do
          allow(Rails.logger).to receive(:info)
          send_webhook(webhook_payload)

          expect(Rails.logger).to have_received(:info)
            .with("Payment failed for user #{user.id}: Card declined")
        end
      end
    end

    context 'signature verification edge cases' do
      it 'rejects webhook with expired timestamp' do
        old_timestamp = 10.minutes.ago.to_i
        event_data = { type: 'customer.subscription.created' }
        sig = generate_stripe_signature(event_data.to_json, old_timestamp, webhook_secret)

        post '/webhooks/stripe',
             params: event_data.to_json,
             headers: {
               'CONTENT_TYPE' => 'application/json',
               'HTTP_STRIPE_SIGNATURE' => sig
             }

        # Note: Stripe's signature verification includes timestamp validation
        # This will fail because the timestamp is too old
        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects webhook with no signature header' do
        event_data = { type: 'customer.subscription.created' }

        post '/webhooks/stripe',
             params: event_data.to_json,
             headers: {
               'CONTENT_TYPE' => 'application/json'
             }

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects webhook with wrong secret' do
        event_data = { type: 'customer.subscription.created' }
        wrong_sig = generate_stripe_signature(event_data.to_json, timestamp, 'wrong_secret')

        post '/webhooks/stripe',
             params: event_data.to_json,
             headers: {
               'CONTENT_TYPE' => 'application/json',
               'HTTP_STRIPE_SIGNATURE' => wrong_sig
             }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'CSRF and authentication bypass' do
      it 'does not require CSRF token' do
        # This test verifies that skip_before_action :verify_authenticity_token is working
        expect {
          send_webhook({ type: 'ping', data: { object: {} } })
        }.not_to raise_error

        expect(response).to have_http_status(:ok)
      end

      it 'does not require user login' do
        # This test verifies that skip_before_action :require_login is working
        expect {
          send_webhook({ type: 'ping', data: { object: {} } })
        }.not_to raise_error

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
