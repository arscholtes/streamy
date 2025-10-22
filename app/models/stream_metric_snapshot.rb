class StreamMetricSnapshot < ApplicationRecord
  # Associations
  belongs_to :stream
  belongs_to :user

  # Validations
  validates :snapshot_at, presence: true
  validates :viewer_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :chat_messages_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :chat_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :peak_viewers, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :unique_chatters, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_stream, ->(stream_id) { where(stream_id: stream_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :since, ->(time) { where('snapshot_at >= ?', time) }
  scope :until, ->(time) { where('snapshot_at <= ?', time) }
  scope :between, ->(start_time, end_time) { where(snapshot_at: start_time..end_time) }
  scope :recent, ->(limit = 100) { order(snapshot_at: :desc).limit(limit) }
  scope :chronological, -> { order(snapshot_at: :asc) }

  # Class methods
  def self.aggregate_for_period(stream_id, start_time, end_time)
    snapshots = for_stream(stream_id).between(start_time, end_time)

    {
      avg_viewers: snapshots.average(:viewer_count)&.round(2) || 0,
      peak_viewers: snapshots.maximum(:peak_viewers) || 0,
      total_chat_messages: snapshots.sum(:chat_messages_count),
      avg_chat_rate: snapshots.average(:chat_rate)&.round(2) || 0,
      unique_chatters: snapshots.maximum(:unique_chatters) || 0,
      snapshot_count: snapshots.count
    }
  end

  def self.latest_for_stream(stream_id)
    for_stream(stream_id).order(snapshot_at: :desc).first
  end

  # Instance methods
  def engagement_score
    return 0 if viewer_count.zero?

    # Calculate engagement as chat rate per viewer
    (chat_rate / viewer_count.to_f).round(2)
  end

  def viewer_growth_from_previous
    previous = self.class
                   .for_stream(stream_id)
                   .where('snapshot_at < ?', snapshot_at)
                   .order(snapshot_at: :desc)
                   .first

    return 0 unless previous

    viewer_count - previous.viewer_count
  end
end
