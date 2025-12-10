# config/routes.rb

Rails.application.routes.draw do
  # Rswag Documentation Endpoints
  if defined?(Rswag)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # ====================================================================
  # API Namespace V1
  # ====================================================================
  namespace :v1 do
    # Public endpoints (No authentication required)
    namespace :public do
      # Public event info - accessible without login (limited fields)
      resources :events, only: [:show]
      # Public voucher showcase - accessible without login
      resources :vouchers, only: [:index, :show]
    end

    # Authentication endpoints
    post 'auth/login', to: 'authentication#login'
    post 'auth/register', to: 'authentication#register'
    post 'auth/refresh_token', to: 'authentication#refresh_token'
    delete 'auth/logout', to: 'authentication#logout'
    post 'auth/send-verification-code', to: 'authentication#send_verification_code'
    post 'auth/verify-email', to: 'authentication#verify_email'
    patch 'auth/password', to: 'authentication#password_update'
    post 'auth/register_invited_vendor', to: 'authentication#register_invited_vendor'
    get 'auth/check_account', to: 'authentication#check_account'
    post 'auth/join_event_as_vendor', to: 'authentication#join_event_as_vendor'

    # Password reset (follow auth route style, flat controller)
    post 'auth/password/request_reset_password', to: 'password_resets#request_reset_password'
    get 'auth/password/verify_reset_password_request', to: 'password_resets#verify_reset_password_request'
    post 'auth/password/reset_password', to: 'password_resets#reset_password'

    # 2. USER MANAGEMENT & PROFILE (Refactored to match /v1/users/profile test path)
    resources :users, only: [:create] do

      # GET /v1/users/profile  <- Maps to users#show
      # PUT /v1/users/profile  <- Maps to users#update
      # This replaces the singular resource :profile to fix the RSpec routing error
      collection do
        # Note: If your controller uses a dedicated action (e.g., profile_show)
        # you would update the 'to:' parameter here. Assuming users#show/update work with current_user.
        get :profile, to: 'users#show'
        put :profile, to: 'users#update'
      end

      # PUT /v1/users/:id/role (Global Role Management)
      member do
        put :role, to: 'users#update_role'
      end
    end

    resources :item_categories
    # 3. GLOBAL TICKET TYPES (Templates - event_id is null)
    resources :ticket_types, only: [:index, :show, :create, :update, :destroy]

    # 4. EVENTS AND ASSOCIATED RESOURCES
    resources :events do
      member do
        delete :force_delete
        patch :restore
      end
      resources :ticket_types, only: [:index, :show, :create, :update, :destroy]
      resources :tickets, only: [:index, :show, :create, :update, :destroy] do
        member do
          delete :force_delete
          patch :cancel_ticket
          patch :restore
        end
      end
      resources :event_locations, only: [:index, :show, :create, :update, :destroy]

      # Vendor invitations
      resources :vendor_invitations, only: [] do
        collection do
          post :generate_link
          get :verify
        end
      end

      # New: Event Staff Management (GET/POST/DELETE)
      resources :staff, only: [:index, :create], controller: 'event_staff' do
        # DELETE /v1/events/:event_id/staff/:user_id
        delete ':user_id', to: 'event_staff#destroy', on: :collection, as: :remove_member
      end

      resources :vendors, controller: 'event_vendors', only: [:index, :create, :update, :destroy] do
        member do
          get :profile, to: 'event_vendor_profiles#show'
          patch :profile, to: 'event_vendor_profiles#update'
          get :stamp_count, to: 'stamp_analytics#count'
        end
      end

      resources :visitors, only: [:index, :show, :create, :update, :destroy]

      resources :voucher_analytics, only: [:index], controller: 'voucher_analytics' do
        collection do
          get :redemption_logs
        end
      end

      resources :vouchers, only: [:index]

      # Nested resource for Event Exhibition Contractor
      resource :event_exhibition_contractor, only: [:show, :create, :destroy]

      resources :event_printing_services do
        resources :event_printing_service_prices, controller: 'event_printing_service_prices'
      end
      resources :event_rentable_items do
        resources :event_rentable_item_prices, controller: 'event_rentable_item_prices'
      end

      resources :exhibitor_kits, only: [:index, :show, :create, :update, :destroy] do
        resources :exhibitor_kit_payments, only: [:index, :show, :update]
      end

      # Lucky Draw feature
      namespace :lucky_draw do
        resources :sessions, controller: 'lucky_draw_sessions' do
          member do
            get :background_manager, path: 'background-manager'
            post :background_manager, path: 'background-manager'
          end
          resources :gifts, only: [:index, :show, :create, :update, :destroy] do
            resources :winners, only: [:create, :destroy], controller: 'gift_winners' do
              collection do
                post :bulk
              end
            end
          end
          resources :participants, only: [:index], controller: 'lucky_draw_participants'
          resources :invalid_participants, only: [:index, :create, :destroy] do
            collection do
              delete :destroy_all
            end
          end
        end
      end

      # Event Metrics moved outside to avoid impacting event resources
    end

    # Visitors stamps
    get 'events/:event_id/visitor-stamps', to: 'visitor_stamps#index'
    post 'visitors/:public_id/stamps', to: 'visitor_stamps#create'

    # 5. GLOBAL TICKET ACTIONS
    # PATCH /v1/tickets/:public_id/check_in
    resources :tickets, only: [] do
      patch ':public_id/check_in', to: 'tickets#global_check_in', on: :collection
      patch ':id/unscan', to: 'tickets#unscan', on: :collection

      # Public endpoints (no auth required)
      post 'find_by_contact', to: 'tickets#find_by_contact', on: :collection
      post 'self_check_in', to: 'tickets#self_check_in', on: :collection
    end

    # 5a. IMPORTS
    post 'imports/tickets', to: 'imports#tickets'   # POST /v1/imports/tickets

    # 5b. TICKET EXPORTS (separate resource for export management)
    resources :ticket_exports, only: [:index, :show, :create], path: 'tickets/exports' do
      # GET /v1/tickets/exports?event_id=1 - List all exports for an event
      # GET /v1/tickets/exports/:id - Download a specific export file
      # POST /v1/tickets/exports - Create new export (generates file)
    end

    # 6. TEAM MEMBERS MANAGEMENT
    resources :team_members, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get 'organizer/:organizer_id', to: 'team_members#organizer_members'
      end
      member do
        patch :toggle_status
      end
    end

    resources :groups do
      resources :members, controller: 'group_members', only: [:index, :create, :update, :destroy]
      resources :affiliates, controller: 'group_affiliates', only: [:index, :create, :destroy]
    end

    # Vendor profile management (vendor-centric, not group-specific)
    resource :vendor_profile, only: [:show, :update]

    # Vendor dashboard
    get 'vendor/dashboard', to: 'vendor_dashboard#index'

    resources :vendors, only: [:index, :show, :create, :update, :destroy] do
      member do
        patch :toggle_status
        get :profile, to: 'vendor_profiles#show'
        patch :profile, to: 'vendor_profiles#update'
      end
    end

    resources :vouchers, only: [:index, :show, :create, :update, :destroy]
    resources :voucher_redemptions, only: [:create]

    # Public route for serving voucher images + vendor profile images
    get '/voucher_images/:filename', to: 'vouchers#serve_image', constraints: { filename: /.+/ }
    get '/vendor_images/:filename', to: 'vendor_profiles#serve_image', constraints: { filename: /.+/ }
    get '/lucky_draw_session_logos/:filename', to: 'lucky_draw/lucky_draw_sessions#serve_logo', constraints: { filename: /.+/ }
    get '/lucky_draw_session_backgrounds/:filename', to: 'lucky_draw/lucky_draw_sessions#serve_background', constraints: { filename: /.+/ }

    # 7. GLOBAL METRICS (replaces analytics)
    scope :metrics do
      # Optimized bulk endpoints (works for all roles)
      get 'events_overview', to: 'analytics#events_overview'
      get 'summary',         to: 'analytics#summary'

      # Individual metrics endpoints (requires org_owner/manager)
      get 'total_tickets',            to: 'analytics#total_tickets'
      get 'total_scanned_tickets',    to: 'analytics#total_scanned_tickets'
      get 'total_unscanned_tickets',  to: 'analytics#total_unscanned_tickets'
      get 'total_amount_price',       to: 'analytics#total_amount_price'
      get 'weekly_registered',        to: 'analytics#weekly_registered_tickets'
      get 'weekly_scanned',           to: 'analytics#weekly_scanned_tickets'
      get 'weekly_sales_amount',      to: 'analytics#weekly_sales_amount'
    end

    # 7c. EVENT METRICS (standalone routes to avoid altering events resource)
    scope :events do
      scope ':event_id' do
        scope :metrics do
          get 'total_tickets',            to: 'event_analytics#total_tickets'
          get 'total_scanned_tickets',    to: 'event_analytics#total_scanned_tickets'
          get 'total_unscanned_tickets',  to: 'event_analytics#total_unscanned_tickets'
          get 'total_amount_price',       to: 'event_analytics#total_amount_price'
          get 'weekly_registered',        to: 'event_analytics#weekly_registered_tickets'
          get 'weekly_scanned',           to: 'event_analytics#weekly_scanned_tickets'
          get 'weekly_sales_amount',      to: 'event_analytics#weekly_sales_amount'
          get 'mall_live_feed',           to: 'event_analytics#mall_live_feed'
        end
      end
    end

    # 7b. GLOBAL METRICS (aliases for analytics) - path-only scope to avoid module nesting
    scope :metrics do
      # Optimized bulk endpoints
      get 'events_overview', to: 'analytics#events_overview'
      get 'summary',         to: 'analytics#summary'

      # Individual metrics endpoints
      get 'total_tickets',            to: 'analytics#total_tickets'
      get 'total_scanned_tickets',    to: 'analytics#total_scanned_tickets'
      get 'total_unscanned_tickets',  to: 'analytics#total_unscanned_tickets'
      get 'total_amount_price',       to: 'analytics#total_amount_price'
      get 'weekly_registered',        to: 'analytics#weekly_registered_tickets'
      get 'weekly_scanned',           to: 'analytics#weekly_scanned_tickets'
      get 'weekly_sales_amount',      to: 'analytics#weekly_sales_amount'
    end

    # 8. API KEYS MANAGEMENT
    resources :api_keys, only: [:index, :create, :destroy]

    # Exhibition Contractors (user accounts with exhibition_contractor role)
    resources :exhibition_contractors, only: [:index, :show, :create, :update, :destroy] do
      member do
        patch :toggle_status
        get :assigned_events
      end
    end

    # Exhibition Contractor Profiles (profile data only)
    resources :exhibition_contractor_profiles, only: [:show, :update]

    resources :rentable_items
    resources :printing_services

    # REMOVED conflicting only: [] definitions
    resources :event_rentable_items, only: [] do
      resources :event_rentable_item_prices, controller: 'event_rentable_item_prices'
    end

    resources :event_printing_services, only: [] do
      resources :event_printing_service_prices, controller: 'event_printing_service_prices'
    end
  end
end
