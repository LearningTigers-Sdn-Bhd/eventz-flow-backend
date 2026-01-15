# Configure ActiveStorage to handle missing vips library gracefully
# This prevents the application from crashing when vips is not installed
# Also ensures Homebrew library path is set up for libvips

Rails.application.config.before_configuration do
  # Ensure Homebrew library path is available for libvips
  # This is especially important when the server starts without direnv/.envrc
  brew_path = `which brew 2>/dev/null`.strip
  if brew_path.present? && !brew_path.empty?
    homebrew_prefix = `brew --prefix 2>/dev/null`.strip
    if homebrew_prefix.present? && !homebrew_prefix.empty?
      lib_path = File.join(homebrew_prefix, 'lib')
      if Dir.exist?(lib_path)
        current_ld_path = ENV['LD_LIBRARY_PATH'] || ''
        unless current_ld_path.include?(lib_path)
          ENV['LD_LIBRARY_PATH'] = "#{lib_path}:#{current_ld_path}".gsub(/^:|:$/, '')
        end

        pkg_config_path = File.join(homebrew_prefix, 'lib', 'pkgconfig')
        if Dir.exist?(pkg_config_path)
          current_pkg_path = ENV['PKG_CONFIG_PATH'] || ''
          unless current_pkg_path.include?(pkg_config_path)
            ENV['PKG_CONFIG_PATH'] = "#{pkg_config_path}:#{current_pkg_path}".gsub(/^:|:$/, '')
          end
        end
      end
    end
  end
end

Rails.application.config.after_initialize do
  begin
    # Try to require vips to see if it's available
    require 'vips'
    # Test if vips actually works by trying to use it
    ::Vips::Image.new_from_file('/dev/null') rescue nil
    # If successful, vips is available and will be used by ActiveStorage
    Rails.logger.info "✅ Vips library is available for image processing (version: #{::Vips::version_string})"
  rescue LoadError, NoMethodError, RuntimeError => e
    # Vips is not available - log warning but don't crash
    Rails.logger.warn "⚠️  Vips library not available: #{e.message}"
    Rails.logger.warn "Image variants using WebP will not be processed. Please install libvips for full functionality."
  end
end
