# app/controllers/streams_controller.rb
# Controller for browsing and viewing streams
class StreamsController < ApplicationController
  before_action :require_login, only: [:edit, :update]
  before_action :set_stream, only: [:show, :edit, :update]
  before_action :authorize_stream_owner, only: [:edit, :update]

  # GET /streams
  # Browse and discover streams
  def index
    @streams = Stream.includes(:user)

    # Filter by status
    if params[:filter] == 'live'
      @streams = @streams.live
    elsif params[:filter] == 'all'
      @streams = @streams.all
    else
      # Default to live streams
      @streams = @streams.live
    end

    # Search functionality
    if params[:search].present?
      @streams = @streams.search(params[:search])
    end

    # Sort
    case params[:sort]
    when 'recent'
      @streams = @streams.recent
    when 'popular'
      @streams = @streams.live.recent # Would be .popular with real viewer counts
    else
      @streams = @streams.recent
    end

    @streams = @streams.page(params[:page]).per(12) # Pagination (requires kaminari gem)

    # Stats for header
    @total_live = Stream.live.count
    @total_streams = Stream.count
  end

  # GET /streams/:id
  # Watch a specific stream
  def show
    @related_streams = Stream.live
                             .where.not(id: @stream.id)
                             .limit(4)
                             .includes(:user)

    # Load recent chat messages
    @chat_messages = @stream.chat_messages
                            .includes(:user)
                            .order(created_at: :asc)
                            .last(100) # Show last 100 messages
  end

  # GET /streams/:id/edit
  # Edit stream settings (owner only)
  def edit
  end

  # PATCH/PUT /streams/:id
  # Update stream settings (owner only)
  def update
    if @stream.update(stream_params)
      redirect_to @stream, notice: 'Stream updated successfully!'
    else
      render :edit
    end
  end

  private

  def set_stream
    @stream = Stream.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to streams_path, alert: 'Stream not found'
  end

  def authorize_stream_owner
    unless current_user && @stream.user_id == current_user.id
      redirect_to streams_path, alert: 'You are not authorized to edit this stream'
    end
  end

  def stream_params
    params.require(:stream).permit(:title)
  end
end
