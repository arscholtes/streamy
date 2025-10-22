class Video < ApplicationRecord
  belongs_to :user
  belongs_to :youtube_account, optional: true
  has_one_attached :file

  # Validations
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 5000 }
  validates :status, presence: true, inclusion: {
    in: %w[pending processing uploaded published failed],
    message: "%{value} is not a valid status"
  }

  # Scopes
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # Callbacks
  before_validation :set_default_status, on: :create

  # Status helpers
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def uploaded?
    status == 'uploaded'
  end

  def published?
    status == 'published'
  end

  def failed?
    status == 'failed'
  end

  # State transitions
  def mark_as_processing!
    update!(status: 'processing')
  end

  def mark_as_uploaded!(youtube_video_id)
    update!(
      status: 'uploaded',
      youtube_video_id: youtube_video_id,
      video_url: "https://youtube.com/watch?v=#{youtube_video_id}"
    )
  end

  def mark_as_published!
    update!(status: 'published')
  end

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      error_message: error_message
    )
  end

  # File validation
  def validate_video_file
    return unless file.attached?

    # Check file size (max 2GB)
    if file.byte_size > 2.gigabytes
      errors.add(:file, 'is too large (maximum is 2GB)')
    end

    # Check content type
    unless file.content_type.in?(%w[video/mp4 video/quicktime video/x-msvideo video/x-ms-wmv])
      errors.add(:file, 'must be a video file (MP4, MOV, AVI, WMV)')
    end
  end

  private

  def set_default_status
    self.status ||= 'pending'
  end
end
