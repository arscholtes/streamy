# app/services/integrations/youtube_upload_service.rb
# Service for uploading videos to YouTube
module Integrations
  class YoutubeUploadService
    attr_reader :video, :youtube_account

    def initialize(video)
      @video = video
      @youtube_account = video.youtube_account
      raise ArgumentError, "Video must have a YouTube account" unless @youtube_account
      raise ArgumentError, "Video must have a file attached" unless video.file.attached?
    end

    def upload!
      video.mark_as_processing!

      begin
        # Get the file path
        file_path = download_file_if_needed

        # Upload to YouTube
        youtube_video_id = perform_upload(file_path)

        # Mark as uploaded
        video.mark_as_uploaded!(youtube_video_id)

        # Clean up temp file if we created one
        File.delete(file_path) if file_path.start_with?(Dir.tmpdir)

        youtube_video_id
      rescue => e
        video.mark_as_failed!(e.message)
        Rails.logger.error("YouTube upload failed for video #{video.id}: #{e.message}")
        raise
      end
    end

    private

    def download_file_if_needed
      # If the file is stored locally, we can use it directly
      # Otherwise, download it to a temp file
      if video.file.service.name == :local || video.file.service.name == :test
        video.file.service.path_for(video.file.key)
      else
        # Download to temp file
        temp_file = Tempfile.new(['video', File.extname(video.file.filename.to_s)])
        temp_file.binmode
        video.file.download { |chunk| temp_file.write(chunk) }
        temp_file.close
        temp_file.path
      end
    end

    def perform_upload(file_path)
      # Use multipart upload for files
      upload_url = 'https://www.googleapis.com/upload/youtube/v3/videos'

      # Prepare metadata
      metadata = {
        snippet: {
          title: video.title,
          description: video.description || '',
          categoryId: video.category_id || '20', # Gaming
          tags: video.tags || []
        },
        status: {
          privacyStatus: video.privacy_status || 'unlisted',
          selfDeclaredMadeForKids: false
        }
      }

      # Use HTTParty with multipart
      response = HTTParty.post(
        upload_url,
        query: { part: 'snippet,status', uploadType: 'multipart' },
        headers: {
          'Authorization' => "Bearer #{youtube_account.access_token}",
          'Content-Type' => 'multipart/related'
        },
        multipart: true,
        body: {
          metadata: metadata.to_json,
          file: File.new(file_path, 'rb')
        }
      )

      if response.success?
        parsed = JSON.parse(response.body, symbolize_names: true)
        parsed[:id]
      else
        error_message = begin
          JSON.parse(response.body)['error']['message']
        rescue
          response.body
        end
        raise APIError, "YouTube upload failed: #{error_message}"
      end
    end

    # Alternative implementation using google-api-client gem (more robust)
    # This would require adding the google-api-client gem to Gemfile
    def perform_upload_with_google_client(file_path)
      require 'google/apis/youtube_v3'
      require 'googleauth'

      youtube = Google::Apis::YoutubeV3::YouTubeService.new
      youtube.authorization = build_authorization

      video_object = Google::Apis::YoutubeV3::Video.new(
        snippet: Google::Apis::YoutubeV3::VideoSnippet.new(
          title: video.title,
          description: video.description || '',
          category_id: video.category_id || '20',
          tags: video.tags || []
        ),
        status: Google::Apis::YoutubeV3::VideoStatus.new(
          privacy_status: video.privacy_status || 'unlisted',
          self_declared_made_for_kids: false
        )
      )

      result = youtube.insert_video(
        'snippet,status',
        video_object,
        upload_source: file_path,
        content_type: video.file.content_type
      )

      result.id
    end

    def build_authorization
      require 'googleauth/stores/file_token_store'

      # Use the stored access token
      auth = Signet::OAuth2::Client.new(
        client_id: CredentialsHelper.youtube.client_id,
        client_secret: CredentialsHelper.youtube.client_secret,
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        access_token: youtube_account.access_token,
        refresh_token: youtube_account.refresh_token,
        expires_at: youtube_account.token_expires_at
      )

      # Refresh if needed
      auth.refresh! if auth.expired?

      # Update tokens if refreshed
      if auth.access_token != youtube_account.access_token
        youtube_account.update!(
          access_token: auth.access_token,
          token_expires_at: auth.expires_at
        )
      end

      auth
    end
  end
end
