module ResourceFormatter
  extend ActiveSupport::Concern

  included do
    def format_resource(resource, options = {})
      include_article = options.fetch(:include_article, false)
      include_author = options.fetch(:include_author, true)

      data = {
        id: resource.id,
        title: resource.title,
        slug: resource.slug,
        meta_description: resource.meta_description,
        status: resource.deleted_at.present? ? 'archived' : resource.status,
        is_gated: resource.is_gated,
        is_official: resource.is_official,
        rejection_reason: resource.rejection_reason,
        view_counts: resource.view_counts,
        priority: resource.priority,
        published_at: resource.published_at,
        created_at: resource.created_at,
        updated_at: resource.updated_at,
        deleted_at: resource.deleted_at,
        header_img_url: format_header_img_urls(resource),
        min_read: calculate_min_read(resource.article),

        topic: resource.resource_topic ? {
          id: resource.resource_topic.id,
          name: resource.resource_topic.name
        } : nil,
        category: resource.resource_category ? {
          id: resource.resource_category.id,
          name: resource.resource_category.name
        } : nil,
        media_type: resource.resource_media_type ? {
          id: resource.resource_media_type.id,
          name: resource.resource_media_type.name
        } : nil
      }

      data[:article] = resource.article if include_article

      if include_author
        data[:author] = {
          id: resource.user.id,
          full_name: resource.user.full_name,
          email: resource.user.email,
          phone: resource.user.phone,
          write_permission: resource.user.resource_write_permission ? {
            status: resource.user.resource_write_permission.status,
            is_official: resource.user.resource_write_permission.is_official
          } : nil
        }
      end

      data
    end

    def format_header_img_urls(resource)
      return nil unless resource.header_img.attached?

      # Check if the blob actually exists (it might have been deleted or orphaned)
      begin
        # Try to access the blob - this will raise RecordNotFound if it doesn't exist
        blob = resource.header_img.blob
        # Verify the blob is actually persisted in the database
        unless blob.persisted?
          Rails.logger.warn "Blob not persisted for resource #{resource.id}"
          return nil
        end
      rescue ActiveRecord::RecordNotFound, NoMethodError => e
        Rails.logger.warn "Blob not found for resource #{resource.id}: #{e.class} - #{e.message}"
        return nil
      end

      # Check if vips is available (variants won't work without it)
      vips_available = Resource.const_defined?(:VIPS_AVAILABLE) ? Resource::VIPS_AVAILABLE : false

      unless vips_available
        # If vips is not available, return original URL for all sizes
        begin
          original_url = url_for(resource.header_img)
          return {
            thumbnail: original_url,
            medium: original_url,
            large: original_url,
            original: original_url
          }
        rescue => e
          Rails.logger.error "Could not generate URL for resource #{resource.id}: #{e.class} - #{e.message}"
          return nil
        end
      end

      # Try to get variants if vips is available
      begin
        {
          thumbnail: url_for(resource.header_img.variant(:thumbnail)),
          medium: url_for(resource.header_img.variant(:medium)),
          large: url_for(resource.header_img.variant(:large)),
          original: url_for(resource.header_img)
        }
      rescue ActiveStorage::InvariableError, LoadError, NoMethodError, ArgumentError, ActiveRecord::RecordNotFound => e
        # If variant generation fails for any reason, fallback to original URL only
        Rails.logger.warn "Could not generate image variants for resource #{resource.id}: #{e.class} - #{e.message}"
        begin
          original_url = url_for(resource.header_img)
          {
            thumbnail: original_url,
            medium: original_url,
            large: original_url,
            original: original_url
          }
        rescue => e2
          Rails.logger.error "Could not generate fallback URL for resource #{resource.id}: #{e2.class} - #{e2.message}"
          nil
        end
      end
    end

    def calculate_min_read(html_content)
      return 1 if html_content.blank?

      text_content = html_content.gsub(/<[^>]*>/, " ") # Strip HTML tags
      word_count = text_content.split.size
      minutes = (word_count / 200.0).ceil

      minutes > 0 ? minutes : 1
    end

    def format_approval_resource(resource)
      data = format_resource(resource, include_article: false, include_author: true)

      # Enhance author info for approval view
      if data[:author]
        data[:author][:phone] = resource.user.phone
        data[:author][:write_permission] = resource.user.resource_write_permission ? {
          status: resource.user.resource_write_permission.status,
          is_official: resource.user.resource_write_permission.is_official
        } : nil
      end

      data
    end
  end
end
