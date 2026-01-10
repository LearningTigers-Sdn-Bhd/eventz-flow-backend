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
        published_at: resource.published_at,
        created_at: resource.created_at,
        updated_at: resource.updated_at,
        deleted_at: resource.deleted_at,
        cover_image_url: resource.respond_to?(:cover_image_url) ? resource.cover_image_url : nil,
        header_img_url: resource.header_img.attached? ? url_for(resource.header_img) : nil,
        
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
          email: resource.user.email
        }
      end

      data
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
