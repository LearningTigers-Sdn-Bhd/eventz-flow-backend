require_relative "boot"

require "rails/all"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"


# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EventzFlowApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Kuala Lumpur"
    config.eager_load_paths << Rails.root.join("app/lib")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # ✅ Add cookie + session middleware
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: '_eventz_flow_session'
    config.middleware.use ActionDispatch::Flash  # optional, safe to include

    # Allow cookies in responses (important for Set-Cookie visibility)
    config.action_dispatch.cookies_serializer = :json

    # --- 1. CORS Configuration (Crucial for React Frontend) ---
    # This must be inserted before other middleware
    # config.middleware.insert_before 0, Rack::Cors do
    #   allow do
    #     origins '*'

    #     resource '*',
    #       headers: :any,
    #       methods: [:get, :post, :put, :patch, :delete, :options, :head]
    #   end
    # end

    # --- Trusted proxies (so request.remote_ip is the REAL client, not the edge) ---
    # The app sits behind Coolify's Traefik reverse proxy. Without this,
    # ActionDispatch::RemoteIp treats the proxy as the client, so anything reading
    # request.remote_ip (JwtService session records, audit logs) attributes every
    # request to the proxy address.
    #
    # NOTE: this does NOT affect Rack::Attack. Rack::Attack::Request is a bare
    # subclass of ::Rack::Request, so its `req.ip` uses Rack's own ip_filter and
    # never consults trusted_proxies. Rack's default filter already treats RFC1918
    # and loopback as proxies, so the per-IP throttles were already keyed on the
    # real client.
    #
    # Rails REPLACES its built-in TRUSTED_PROXIES when this is set (see
    # action_dispatch/middleware/remote_ip.rb), so the IPv6 entries below must be
    # listed explicitly — omitting them silently breaks remote_ip on any IPv6 hop.
    # Scope trust to private/Docker-overlay ranges only, never 0.0.0.0/0.
    # Override/extend via TRUSTED_PROXIES="cidr1,cidr2" if the edge moves to a public IP.
    default_trusted = [
      IPAddr.new('10.0.0.0/8'),     # Docker overlay / RFC1918
      IPAddr.new('172.16.0.0/12'),  # Docker default bridge / RFC1918
      IPAddr.new('192.168.0.0/16'), # RFC1918
      IPAddr.new('127.0.0.0/8'),    # IPv4 loopback
      IPAddr.new('::1'),            # IPv6 loopback
      IPAddr.new('fc00::/7'),       # IPv6 unique local (Docker IPv6 overlay)
    ].freeze
    extra_trusted = ENV.fetch('TRUSTED_PROXIES', '').split(',').map(&:strip).reject(&:empty?)
    config.action_dispatch.trusted_proxies = default_trusted + extra_trusted.map { |cidr| IPAddr.new(cidr) }

    # --- Rate Limiting ---
    config.middleware.use Rack::Attack

    # --- 2. Active Job Adapter (for Sidekiq) ---
    # Set the queue adapter for webhooks and notifications
    config.active_job.queue_adapter = :sidekiq

    # --- 3. Timezone Configuration (Rails 8.1 compatibility) ---
    # Preserve full timezone information in time conversions
    config.active_support.to_time_preserves_timezone = :zone
  end
end
