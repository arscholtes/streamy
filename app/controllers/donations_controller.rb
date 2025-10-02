class DonationsController < ApplicationController
  before_action :require_login
  before_action :find_streamer, only: [:new, :create]

  # GET /users/:username/donate
  def new
    @amounts = [500, 1000, 2000, 5000, 10000] # Preset amounts in cents
  end

  # POST /users/:username/donate
  def create
    amount_cents = params[:amount_cents].to_i
    message = params[:message]

    if amount_cents < 100 # Minimum $1.00
      flash[:error] = "Minimum donation amount is $1.00"
      redirect_to new_user_donation_path(@streamer.username) and return
    end

    # Check if streamer has Stripe Connect enabled
    unless @streamer.stripe_account&.charges_enabled
      flash[:error] = "This streamer hasn't set up donations yet"
      redirect_to user_path(@streamer) and return
    end

    service = PaymentService.new(
      payer: current_user,
      recipient: @streamer,
      amount_cents: amount_cents,
      payment_type: 'donation'
    )

    begin
      # Create payment intent
      intent = service.create_payment_intent(
        description: "Donation to #{@streamer.username}",
        metadata: {
          message: message,
          streamer_id: @streamer.id,
          streamer_username: @streamer.username
        }
      )

      # Create checkout session for the payment intent
      session = Stripe::Checkout::Session.create({
        mode: 'payment',
        payment_intent_data: {
          application_fee_amount: service.platform_fee,
          transfer_data: {
            destination: @streamer.stripe_account.stripe_id
          },
          metadata: {
            user_id: current_user.id,
            recipient_id: @streamer.id,
            payment_type: 'donation',
            message: message
          }
        },
        line_items: [{
          price_data: {
            currency: 'usd',
            product_data: {
              name: "Donation to #{@streamer.username}",
              description: message.present? ? message : "Support #{@streamer.username}"
            },
            unit_amount: amount_cents
          },
          quantity: 1
        }],
        success_url: donation_success_url(username: @streamer.username),
        cancel_url: new_user_donation_url(@streamer.username)
      })

      redirect_to session.url, allow_other_host: true
    rescue => e
      Rails.logger.error("Donation creation error: #{e.message}")
      flash[:error] = "Failed to process donation. Please try again."
      redirect_to new_user_donation_path(@streamer.username)
    end
  end

  # GET /users/:username/donate/success
  def success
    @streamer = User.find_by!(username: params[:username])
    flash[:success] = "Thank you for your donation to #{@streamer.username}!"
    redirect_to user_path(@streamer)
  end

  # GET /donations (user's donation history)
  def index
    @sent_donations = current_user.payments
                                   .where(payment_type: ['donation', 'tip'])
                                   .includes(:recipient)
                                   .order(created_at: :desc)
                                   .page(params[:page])

    @received_donations = current_user.received_payments
                                       .where(payment_type: ['donation', 'tip'])
                                       .includes(:user)
                                       .order(created_at: :desc)
                                       .page(params[:page])
  end

  private

  def find_streamer
    @streamer = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Streamer not found"
    redirect_to root_path
  end
end
