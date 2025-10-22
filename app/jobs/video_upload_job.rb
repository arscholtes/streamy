# app/jobs/video_upload_job.rb
# Background job for uploading videos to YouTube
class VideoUploadJob < ApplicationJob
  queue_as :default

  # Retry on rate limit errors, but not on other API errors
  retry_on Integrations::RateLimitError, wait: 1.hour, attempts: 3
  retry_on Integrations::APIError, wait: :exponentially_longer, attempts: 5

  def perform(video_id)
    video = Video.find_by(id: video_id)

    unless video
      Rails.logger.warn("Video not found: #{video_id}")
      return
    end

    unless video.youtube_account
      video.mark_as_failed!("No YouTube account associated with video")
      return
    end

    unless video.file.attached?
      video.mark_as_failed!("No file attached to video")
      return
    end

    Rails.logger.info("Starting YouTube upload for video #{video.id}")

    upload_service = Integrations::YoutubeUploadService.new(video)
    youtube_video_id = upload_service.upload!

    Rails.logger.info("YouTube upload completed for video #{video.id}: #{youtube_video_id}")

    # Optionally broadcast to user via ActionCable
    broadcast_upload_complete(video)
  rescue StandardError => e
    Rails.logger.error("Video upload job failed for video #{video_id}: #{e.message}")
    video&.mark_as_failed!(e.message)
    raise
  end

  private

  def broadcast_upload_complete(video)
    # ActionCable broadcast to notify user
    # ActionCable.server.broadcast(
    #   "user_#{video.user_id}_videos",
    #   {
    #     type: 'upload_complete',
    #     video_id: video.id,
    #     youtube_video_id: video.youtube_video_id,
    #     video_url: video.video_url
    #   }
    # )
  end
end
