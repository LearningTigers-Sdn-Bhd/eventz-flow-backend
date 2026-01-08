# db/seeds/resources.rb

puts "\n--- 6. Generating Resource Posts ---"

# Ensure we have required data
topics = ResourceTopic.all
categories = ResourceCategory.all
media_types = ResourceMediaType.all
writers = User.joins(:resource_write_permission).all

if topics.empty? || categories.empty? || media_types.empty? || writers.empty?
  puts "⚠️ Missing prerequisite data (Topics, Categories, Media Types, or Writers). Skipping resource generation."
else
  statuses = Resource.statuses.keys # ["draft", "pending_review", "published", "rejected"]
  
  # Generate 40 posts with varied data
  40.times do |i|
    status = statuses[i % statuses.length]
    title = "#{Faker::Company.catch_phrase} #{i + 1}"
    
    # Create a structured article with 3 sections (Header + Paragraph)
    article_content = 3.times.map do |j|
      header = Faker::Company.bs.capitalize
      # Generate approximately 250 words per paragraph
      paragraph = Faker::Lorem.sentence(word_count: 250)
      "<h2>#{header}</h2><p>#{paragraph}</p>"
    end.join("\n")

    # Create the resource
    resource = Resource.new(
      title: title,
      article: article_content,
      meta_description: Faker::Lorem.sentence,
      user: writers.sample,
      resource_topic: topics.sample,
      resource_category: categories.sample,
      resource_media_type: media_types.sample,
      status: status,
      is_gated: [true, false].sample,
      is_official: [true, false].sample,
      view_counts: rand(0..1000)
    )

    # Set specific fields based on status
    if status == 'published'
      resource.published_at = Time.current - rand(1..30).days
    elsif status == 'rejected'
      resource.rejection_reason = "This content does not align with our current guidelines for #{resource.resource_topic.name}."
    end

    # Make every 8th post archived (deleted)
    if i % 8 == 0
      resource.deleted_at = Time.current - rand(1..5).days
    end

    if resource.save
      # success
    else
      puts "  ❌ Failed to create post: #{title}. Errors: #{resource.errors.full_messages.join(', ')}"
    end
  end

  puts "Created #{Resource.unscoped.count} Resource Posts (including archived)."
end
