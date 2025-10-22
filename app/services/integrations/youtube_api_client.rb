# app/services/integrations/youtube_api_client.rb
# YouTube Data API v3 client
module Integrations
  class YoutubeApiClient < BaseApiClient
    def api_base_url
      'https://www.googleapis.com/youtube/v3'
    end

    # Get the authenticated user's channel info
    # Returns channel details including subscriber count
    def fetch_channel_info
      response = get('/channels', params: {
        part: 'snippet,statistics,contentDetails',
        mine: true
      })

      return nil if response[:items].blank?

      channel = response[:items].first
      {
        id: channel[:id],
        title: channel[:snippet][:title],
        description: channel[:snippet][:description],
        custom_url: channel[:snippet][:customUrl],
        thumbnail_url: channel[:snippet][:thumbnails][:high][:url],
        subscriber_count: channel[:statistics][:subscriberCount].to_i,
        video_count: channel[:statistics][:videoCount].to_i,
        view_count: channel[:statistics][:viewCount].to_i,
        uploads_playlist_id: channel[:contentDetails][:relatedPlaylists][:uploads]
      }
    end

    # Get videos from the channel's uploads playlist
    def fetch_recent_videos(max_results: 10)
      # First get the channel info to get the uploads playlist ID
      channel = fetch_channel_info
      return [] unless channel && channel[:uploads_playlist_id]

      response = get('/playlistItems', params: {
        part: 'snippet,contentDetails',
        playlistId: channel[:uploads_playlist_id],
        maxResults: max_results
      })

      return [] if response[:items].blank?

      response[:items].map do |item|
        {
          id: item[:contentDetails][:videoId],
          title: item[:snippet][:title],
          description: item[:snippet][:description],
          thumbnail_url: item[:snippet][:thumbnails][:high][:url],
          published_at: item[:snippet][:publishedAt]
        }
      end
    end

    # Upload a video to YouTube
    # @param file_path [String] Path to the video file
    # @param title [String] Video title
    # @param description [String] Video description
    # @param privacy_status [String] 'public', 'unlisted', or 'private'
    # @param category_id [String] YouTube category ID (default: 20 = Gaming)
    def upload_video(file_path:, title:, description: '', privacy_status: 'unlisted', category_id: '20')
      # For video uploads, we need to use a multipart upload
      # This is a simplified version - in production you'd want resumable uploads
      # for larger files using the YouTube Upload API
      upload_url = 'https://www.googleapis.com/upload/youtube/v3/videos'

      metadata = {
        snippet: {
          title: title,
          description: description,
          categoryId: category_id
        },
        status: {
          privacyStatus: privacy_status
        }
      }

      # Note: Actual file upload requires multipart/form-data
      # This is a placeholder - you'll need to use a library like
      # RestClient or HTTParty's multipart support
      {
        upload_url: upload_url,
        metadata: metadata,
        file_path: file_path
      }
    end

    # Create a Short (YouTube Shorts)
    # Shorts are videos < 60 seconds with specific format
    def create_short(file_path:, title:, description: '')
      # Shorts are created the same way as regular videos,
      # but YouTube automatically detects them if they're vertical and < 60s
      upload_video(
        file_path: file_path,
        title: title,
        description: "#{description} #Shorts",
        privacy_status: 'public',
        category_id: '20' # Gaming
      )
    end

    # Get video statistics
    def fetch_video_stats(video_id)
      response = get('/videos', params: {
        part: 'statistics,snippet',
        id: video_id
      })

      return nil if response[:items].blank?

      video = response[:items].first
      {
        id: video[:id],
        title: video[:snippet][:title],
        view_count: video[:statistics][:viewCount].to_i,
        like_count: video[:statistics][:likeCount].to_i,
        comment_count: video[:statistics][:commentCount].to_i
      }
    end
  end
end
