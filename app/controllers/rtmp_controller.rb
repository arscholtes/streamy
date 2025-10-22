class RtmpController < ApplicationController
  # Skip CSRF verification for RTMP auth requests from MediaMTX
  skip_before_action :verify_authenticity_token

  # POST /rtmp/auth
  # MediaMTX authentication webhook - validates stream key
  def auth
    stream_key = params[:key] || params[:name] # MediaMTX can send either

    if stream_key.blank?
      Rails.logger.warn "RTMP Auth: No stream key provided"
      render plain: 'No stream key provided', status: :unauthorized
      return
    end

    # Find user by stream key
    user = User.find_by(stream_key: stream_key)

    if user
      # Valid stream key - allow streaming
      Rails.logger.info "✅ RTMP Auth: Stream key validated for user #{user.username} (ID: #{user.id})"

      # Log authentication attempt
      Rails.cache.write("rtmp:last_auth:#{user.id}", {
        timestamp: Time.current,
        ip: request.remote_ip,
        user_agent: request.user_agent
      }, expires_in: 1.hour)

      render plain: 'OK', status: :ok
    else
      # Invalid stream key - deny streaming
      Rails.logger.warn "❌ RTMP Auth: Invalid stream key attempted: #{stream_key[0..8]}..."
      render plain: 'Invalid stream key', status: :unauthorized
    end
  end

  # POST /rtmp/stream_start
  # MediaMTX webhook when stream starts
  def stream_start
    # Handle both old and new MediaMTX webhook formats
    stream_key = params[:path] || params[:key] || params[:name]
    user = User.find_by(stream_key: stream_key)

    unless user
      Rails.logger.error "Stream start: User not found for key"
      render plain: 'User not found', status: :not_found
      return
    end

    Rails.logger.info "🔴 Stream START: #{user.username}"

    # Create or update stream record
    stream = user.streams.find_or_create_by(stream_key: stream_key) do |s|
      s.title = "#{user.username}'s Stream"
      s.status = 'offline'
    end

    stream.update!(
      status: 'live',
      started_at: Time.current,
      playback_path: build_playback_url(stream_key),
      viewer_count: 0
    )

    # Broadcast stream start to overlay channel
    begin
      OverlayChannel.broadcast_to(user, {
        type: 'stream_status_change',
        status: 'live',
        stream_id: stream.id,
        timestamp: Time.current.to_i
      })
    rescue => e
      Rails.logger.error "Failed to broadcast stream start: #{e.message}"
    end

    # Trigger any stream start hooks (e.g., Discord notifications)
    StreamStartJob.perform_later(stream.id) if defined?(StreamStartJob)

    render plain: 'OK', status: :ok
  end

  # POST /rtmp/stream_stop
  # MediaMTX webhook when stream stops
  def stream_stop
    # Handle both old and new MediaMTX webhook formats
    stream_key = params[:path] || params[:key] || params[:name]
    user = User.find_by(stream_key: stream_key)

    unless user
      Rails.logger.error "Stream stop: User not found for key"
      render plain: 'User not found', status: :not_found
      return
    end

    Rails.logger.info "⚫ Stream STOP: #{user.username}"

    # Find active stream
    stream = user.streams.find_by(stream_key: stream_key, status: 'live')

    if stream
      # Calculate stream duration
      duration = stream.started_at ? (Time.current - stream.started_at).to_i : 0

      stream.update!(
        status: 'offline',
        ended_at: Time.current,
        duration_seconds: duration
      )

      # Broadcast stream stop to overlay channel
      begin
        OverlayChannel.broadcast_to(user, {
          type: 'stream_status_change',
          status: 'offline',
          stream_id: stream.id,
          duration: duration,
          timestamp: Time.current.to_i
        })
      rescue => e
        Rails.logger.error "Failed to broadcast stream stop: #{e.message}"
      end

      # Trigger any stream stop hooks
      StreamStopJob.perform_later(stream.id) if defined?(StreamStopJob)
    end

    render plain: 'OK', status: :ok
  end

  # POST /rtmp/viewer_update
  # MediaMTX webhook for viewer count updates (if configured)
  def viewer_update
    stream_key = params[:key] || params[:name]
    viewer_count = params[:viewers]&.to_i || 0

    user = User.find_by(stream_key: stream_key)
    return render plain: 'OK', status: :ok unless user

    # Update viewer count on active stream
    stream = user.streams.find_by(stream_key: stream_key, status: 'live')
    if stream
      stream.update(viewer_count: viewer_count)

      # Broadcast viewer count update
      begin
        OverlayChannel.broadcast_to(user, {
          type: 'viewer_count_update',
          viewer_count: viewer_count,
          timestamp: Time.current.to_i
        })
      rescue => e
        Rails.logger.error "Failed to broadcast viewer count: #{e.message}"
      end
    end

    render plain: 'OK', status: :ok
  end

  # GET /rtmp/status
  # Check RTMP service status
  def status
    render json: {
      status: 'operational',
      mediamtx_configured: true,
      webhooks_enabled: true,
      timestamp: Time.current.iso8601
    }
  end

  # POST /rtmp/webhooks/publish
  # MediaMTX runOnPublish webhook - called when stream starts
  def publish
    path = params[:path]
    stream_key = path&.gsub(%r{^/}, '') # Remove leading slash

    if stream_key.blank?
      Rails.logger.warn "Publish webhook: No path provided"
      render plain: 'No path provided', status: :bad_request
      return
    end

    user = User.find_by(stream_key: stream_key)

    unless user
      Rails.logger.error "Publish webhook: User not found for stream key #{stream_key[0..8]}..."
      render plain: 'User not found', status: :not_found
      return
    end

    Rails.logger.info "🔴 PUBLISH: #{user.username} started streaming (key: #{stream_key[0..8]}...)"

    # Create or find the stream
    stream = user.streams.find_or_initialize_by(stream_key: stream_key) do |s|
      s.title = "#{user.username}'s Stream"
    end

    # Update stream to live status
    stream.update!(
      status: 'live',
      started_at: Time.current,
      ended_at: nil,
      playback_path: build_playback_url(stream_key),
      viewer_count: 0
    )

    # Broadcast to Action Cable
    begin
      OverlayChannel.broadcast_to(user, {
        type: 'stream_status_change',
        status: 'live',
        stream_id: stream.id,
        timestamp: Time.current.to_i
      })
    rescue => e
      Rails.logger.error "Failed to broadcast stream start: #{e.message}"
    end

    # Trigger background job if defined
    StreamStartJob.perform_later(stream.id) if defined?(StreamStartJob)

    render plain: 'OK', status: :ok
  end

  # POST /rtmp/webhooks/unpublish
  # MediaMTX runOnUnPublish webhook - called when stream stops
  def unpublish
    path = params[:path]
    stream_key = path&.gsub(%r{^/}, '') # Remove leading slash

    if stream_key.blank?
      Rails.logger.warn "Unpublish webhook: No path provided"
      render plain: 'No path provided', status: :bad_request
      return
    end

    user = User.find_by(stream_key: stream_key)

    unless user
      Rails.logger.error "Unpublish webhook: User not found for stream key"
      render plain: 'User not found', status: :not_found
      return
    end

    Rails.logger.info "⚫ UNPUBLISH: #{user.username} stopped streaming"

    # Find the active stream
    stream = user.streams.find_by(stream_key: stream_key, status: 'live')

    if stream
      duration = stream.started_at ? (Time.current - stream.started_at).to_i : 0

      stream.update!(
        status: 'offline',
        ended_at: Time.current,
        duration_seconds: duration
      )

      # Broadcast to Action Cable
      begin
        OverlayChannel.broadcast_to(user, {
          type: 'stream_status_change',
          status: 'offline',
          stream_id: stream.id,
          duration: duration,
          timestamp: Time.current.to_i
        })
      rescue => e
        Rails.logger.error "Failed to broadcast stream stop: #{e.message}"
      end

      # Trigger background job if defined
      StreamStopJob.perform_later(stream.id) if defined?(StreamStopJob)
    end

    render plain: 'OK', status: :ok
  end

  private

  def build_playback_url(stream_key)
    # Build HLS playback URL
    # In production, this would use your CDN domain
    host = ENV['MEDIAMTX_HOST'] || 'localhost'
    port = ENV['MEDIAMTX_HLS_PORT'] || '8889'
    "http://#{host}:#{port}/#{stream_key}/index.m3u8"
  end
end
