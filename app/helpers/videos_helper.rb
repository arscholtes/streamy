module VideosHelper
  def status_color_class(status)
    case status
    when 'pending' then 'text-yellow-400'
    when 'processing' then 'text-blue-400'
    when 'uploaded' then 'text-green-400'
    when 'published' then 'text-purple-400'
    when 'failed' then 'text-red-400'
    else 'text-gray-400'
    end
  end

  def status_badge_class(status)
    case status
    when 'pending' then 'bg-yellow-600'
    when 'processing' then 'bg-blue-600'
    when 'uploaded' then 'bg-green-600'
    when 'published' then 'bg-purple-600'
    when 'failed' then 'bg-red-600'
    else 'bg-gray-600'
    end
  end

  def video_category_name(category_id)
    categories = {
      '10' => 'Music',
      '17' => 'Sports',
      '20' => 'Gaming',
      '22' => 'People & Blogs',
      '24' => 'Entertainment',
      '27' => 'Education',
      '28' => 'Science & Technology'
    }
    categories[category_id] || "Category #{category_id}"
  end
end
