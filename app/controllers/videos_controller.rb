# app/controllers/videos_controller.rb
class VideosController < ApplicationController
  before_action :require_login
  before_action :set_video, only: [:show, :edit, :update, :destroy, :upload_to_youtube]

  # GET /videos
  def index
    @videos = current_user.videos.recent.page(params[:page]).per(20)
  end

  # GET /videos/:id
  def show
  end

  # GET /videos/new
  def new
    @video = current_user.videos.build
    @youtube_accounts = current_user.youtube_account ? [current_user.youtube_account] : []
  end

  # POST /videos
  def create
    @video = current_user.videos.build(video_params)

    if @video.save
      # Attach the file if provided
      if params[:video][:file].present?
        @video.file.attach(params[:video][:file])
      end

      flash[:success] = "Video created successfully!"
      redirect_to @video
    else
      @youtube_accounts = current_user.youtube_account ? [current_user.youtube_account] : []
      flash.now[:error] = "Failed to create video: #{@video.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  # GET /videos/:id/edit
  def edit
    @youtube_accounts = current_user.youtube_account ? [current_user.youtube_account] : []
  end

  # PATCH /videos/:id
  def update
    if @video.update(video_params)
      # Attach new file if provided
      if params[:video][:file].present?
        @video.file.attach(params[:video][:file])
      end

      flash[:success] = "Video updated successfully!"
      redirect_to @video
    else
      @youtube_accounts = current_user.youtube_account ? [current_user.youtube_account] : []
      flash.now[:error] = "Failed to update video: #{@video.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /videos/:id
  def destroy
    @video.destroy
    flash[:success] = "Video deleted successfully!"
    redirect_to videos_path
  end

  # POST /videos/:id/upload_to_youtube
  def upload_to_youtube
    unless @video.youtube_account
      flash[:error] = "Please select a YouTube account first"
      redirect_to edit_video_path(@video) and return
    end

    unless @video.file.attached?
      flash[:error] = "Please upload a video file first"
      redirect_to edit_video_path(@video) and return
    end

    # Validate file
    @video.validate_video_file
    if @video.errors.any?
      flash[:error] = @video.errors.full_messages.join(', ')
      redirect_to edit_video_path(@video) and return
    end

    # Enqueue upload job
    VideoUploadJob.perform_later(@video.id)

    flash[:success] = "Video upload to YouTube started! We'll notify you when it's complete."
    redirect_to @video
  end

  private

  def set_video
    @video = current_user.videos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Video not found"
    redirect_to videos_path
  end

  def video_params
    permitted = params.require(:video).permit(
      :title,
      :description,
      :youtube_account_id,
      :privacy_status,
      :category_id,
      :tags
    )

    # Convert comma-separated tags string to array
    if permitted[:tags].is_a?(String)
      permitted[:tags] = permitted[:tags].split(',').map(&:strip).reject(&:blank?)
    end

    permitted
  end
end
