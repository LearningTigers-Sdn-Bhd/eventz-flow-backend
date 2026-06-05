# config/routes.rb

Rails.application.routes.draw do
  # Mount LetterOpenerWeb for email preview in development
  if Rails.env.development?
    require 'letter_opener_web' # Explicitly require the gem
    mount LetterOpenerWeb::Engine, at: '/letter_opener'
  end

  # Rswag Documentation Endpoints
  if defined?(Rswag)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  get 'up' => 'rails/health#show', as: :rails_health_check

  # ====================================================================
  # API Namespace V1
  # ====================================================================
  namespace :v1 do
    # Public endpoints (No authentication required)
    namespace :public do
      post 'resend/webhook', to: 'resend_webhooks#create'
      # Public event info - accessible without login (limited fields)
      resources :events, only: [:show], param: :slug do
        get :business_matching_events, on: :member
        # Public check-in endpoint - scoped to event
        resource :check_in, only: %i[show create], controller: 'check_ins'
        # Public check-in display settings
        resource :check_in_display, only: [:show], controller: 'check_in_displays'
      end
      # Public voucher showcase - accessible without login
      resources :vouchers, only: %i[index show]
      # Public seating plans
      resources :plans, only: %i[show]
      # Public booking details
      resources :bookings, only: [:show]

      # Public registration for walk-ins
      post 'payments/webhook', to: 'payments#webhook'
      scope 'events/:event_slug' do
        get 'registration_forms', to: 'registrations#registration_forms'
        get 'ticket_types', to: 'registrations#ticket_types'
        get 'registration_status', to: 'registrations#registration_status'
        get 'pass_bundles/:token', to: 'registrations#pass_bundle'
        get 'ticket_rsvp/:token', to: 'ticket_rsvps#show'
        post 'ticket_rsvp/:token/confirm', to: 'ticket_rsvps#confirm'
        post 'ticket_rsvp/:token/decline', to: 'ticket_rsvps#decline'
        resources :tickets, only: [:show]
        get 'exhibitor_booth_prices', to: 'exhibitor_registrations#booth_prices'
        post 'register_exhibitor', to: 'exhibitor_registrations#create'
        patch 'register_exhibitor', to: 'exhibitor_registrations#update'
        get 'exhibitor_registration_status', to: 'exhibitor_registrations#status'
        post 'exhibitor_payment_proof', to: 'exhibitor_registrations#upload_payment_proof'
        delete 'exhibitor_payment_proof', to: 'exhibitor_registrations#remove_payment_proof'
        post 'payments/create_order', to: 'payments#create_order'
        post 'payments/verify', to: 'payments#verify'
        match 'payments/callback', to: 'payments#callback', via: %i[get post]
        post 'exhibitor_payments/create_order', to: 'exhibitor_payments#create_order'
        post 'exhibitor_payments/verify', to: 'exhibitor_payments#verify'
        match 'exhibitor_payments/callback', to: 'exhibitor_payments#callback', via: %i[get post]
        post 'register', to: 'registrations#create'
      end

      # RSVP endpoints for wedding invitations
      scope 'events/:slug' do
        get 'rsvp/:public_id', to: 'rsvp#show'
        post 'rsvp/:public_id/respond', to: 'rsvp#respond_rsvp'
        get 'wishes', to: 'wishes#index'
        post 'wishes', to: 'wishes#create'
      end
    end

    # Authentication endpoints
    post 'auth/login', to: 'authentication#login'
    post 'auth/register', to: 'authentication#register'
    post 'auth/refresh_token', to: 'authentication#refresh_token'
    delete 'auth/logout', to: 'authentication#logout'
    get 'auth/sessions', to: 'authentication#sessions'
    delete 'auth/sessions/:id', to: 'authentication#revoke_session'
    post 'auth/send-verification-code', to: 'authentication#send_verification_code'
    post 'auth/verify-email', to: 'authentication#verify_email'
    patch 'auth/password', to: 'authentication#password_update'
    post 'auth/register_invited_vendor', to: 'authentication#register_invited_vendor'
    get 'auth/check_account', to: 'authentication#check_account'
    post 'auth/join_event_as_vendor', to: 'authentication#join_event_as_vendor'
    resources :email_deliveries, only: %i[index show] do
      post :resend, on: :member
    end

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
        # NOTE: If your controller uses a dedicated action (e.g., profile_show)
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
    resources :ticket_types, only: %i[index show create update destroy] do
      resources :price_tiers, controller: 'ticket_type_price_tiers'
    end

    # 4. EVENTS AND ASSOCIATED RESOURCES
    resources :events do
      member do
        delete :force_delete
        patch :restore
      end
      resources :ticket_types, only: %i[index show create update destroy] do
        resources :price_tiers, controller: 'ticket_type_price_tiers'
      end
      resources :plans, shallow: true do
        resources :plan_objects, only: %i[create destroy] do
          collection do
            patch :batch
            post :batch_create
            delete :batch_destroy
          end
        end
        resources :assignments, controller: 'table_assignments', only: %i[create update destroy], param: :ticket_id
        resources :seating_groups, controller: 'seating_groups', shallow: false,
                                   only: %i[index create update destroy] do
          member do
            post :members, action: :add_member
            delete 'members/:member_id', action: :remove_member, as: :member
            post :assign_to_table
          end
        end
        post :auto_distribute, on: :member
        get :export, on: :member
      end
      resources :tickets, only: %i[index show create update destroy] do
        member do
          delete :force_delete
          patch :cancel_ticket
          patch :restore
          post :resend_confirmation_email
        end
      end
      resources :pass_bundles, only: %i[index show create update destroy]
      resources :event_locations, only: %i[index show create update destroy]
      resources :registration_forms, only: %i[index show create update destroy] do
        resource :rsvp_setting, only: %i[show update], controller: 'registration_form_rsvp_settings'
      end
      resources :exhibitor_booth_prices, only: %i[index create]
      resources :exhibitor_zones, only: %i[index create]

      # Payment gateway settings (singular - one per event)
      resource :event_payment_gateway, only: %i[show create update destroy]

      # Vendor invitations
      resources :vendor_invitations, only: [] do
        collection do
          post :generate_link
          get :verify
        end
      end

      # New: Event Staff Management (GET/POST/DELETE)
      resources :staff, only: %i[index create], controller: 'event_staff' do
        # DELETE /v1/events/:event_id/staff/:user_id
        delete ':user_id', to: 'event_staff#destroy', on: :collection, as: :remove_member
      end

      resources :vendors, controller: 'event_vendors', only: %i[index create update destroy] do
        member do
          get :profile, to: 'event_vendor_profiles#show'
          patch :profile, to: 'event_vendor_profiles#update'
          get :lead_count, to: 'lead_analytics#count'
        end
      end

      resources :visitors, only: %i[index show create update destroy]

      resources :tickets, only: [] do
        member do
          patch 'application/approve', to: 'ticket_applications#approve'
          patch 'application/reject', to: 'ticket_applications#reject'
          post 'application/resend_rsvp', to: 'ticket_applications#resend_rsvp'
        end
      end

      resources :wishes, only: %i[index destroy] do
        member do
          patch :approve
          patch :reject
        end
      end

      resources :voucher_analytics, only: [:index], controller: 'voucher_analytics' do
        collection do
          get :redemption_logs
        end
      end

      resources :vouchers, only: [:index]

      # Nested resource for Event Exhibition Contractor
      resource :event_exhibition_contractor, only: %i[show create destroy]

      resources :event_printing_services, only: %i[index show create update destroy] do
        resources :event_printing_service_prices, controller: 'event_printing_service_prices'
      end

      get 'business_matching_events', on: :member # New route for business matching events
      get 'organizer_payment_detail', on: :member # Get organizer's bank details for payment

      # NOTE: Create action disabled - items are now auto-linked when contractor is assigned to event
      # resources :event_rentable_items do
      resources :event_rentable_items, only: %i[index show update destroy] do
        resources :event_rentable_item_prices, controller: 'event_rentable_item_prices'
      end

      resources :exhibitor_kits, only: %i[index show create update destroy] do
        member do
          post :submit_order
        end
        resources :exhibitor_kit_payments, only: %i[index show update]
        resources :exhibitor_team_member_payments, only: %i[index show create update]

        namespace :exhibitor_team_member_payments do
          resource :razorpay, only: [], controller: 'razorpay' do
            post :create_order
            post :verify
            post :callback
            get :callback
          end
        end
      end

      # Exhibitor team member limit settings (singular - one per event)
      resource :exhibitor_team_member_limit, only: %i[show create update destroy]

      # Check-in display settings (singular - one per event)
      resource :check_in_display, only: %i[show update] do
        post :announce, on: :member
      end

      # Received payments for payees (contractors/org_owners)
      resources :received_payments, only: [:index]

      # Lucky Draw feature
      namespace :lucky_draw do
        resources :sessions, controller: 'lucky_draw_sessions' do
          member do
            get :background_manager, path: 'background-manager'
            post :background_manager, path: 'background-manager'
          end
          resources :gifts, only: %i[index show create update destroy] do
            resources :winners, only: %i[create destroy], controller: 'gift_winners' do
              member do
                post :notify
              end
              collection do
                post :bulk
              end
            end
          end
          resources :participants, only: [:index], controller: 'lucky_draw_participants'
          resources :invalid_participants, only: %i[index create destroy] do
            member do
              post :notify
            end
            collection do
              delete :destroy_all
            end
          end
        end
      end

      # Prize Roulette feature
      namespace :roulette do
        resources :sessions, controller: 'roulette_sessions' do
          member do
            get :background_manager, path: 'background-manager'
            post :background_manager, path: 'background-manager'
          end
          resources :assigns, only: %i[index create destroy], controller: 'roulette_assigns'
          resources :prizes, only: %i[index show create update destroy], controller: 'roulette_prizes'
          resources :winners, only: %i[index create destroy], controller: 'roulette_winners' do
            member do
              post :notify
            end
          end
          resources :participants, only: [:show], controller: 'roulette_participants'
        end
      end

      # Event Metrics moved outside to avoid impacting event resources

      # Event-scoped API keys
      resources :api_keys, only: %i[index create destroy], controller: 'event_api_keys'
    end

    # Seat Ticketing
    namespace :seat_ticketing do
      resources :public_sessions, only: %i[index show] do
        member do
          get :section_seats
          post :checkout
        end
      end

      get 'checkout_sessions/:id', to: 'checkout_sessions#show'
      post 'checkout_sessions/:id/clear_locks', to: 'checkout_sessions#clear_locks'
      post 'checkout_sessions/:id/heartbeat', to: 'checkout_sessions#heartbeat'
      resources :sessions do
        member do
          patch :bulk_update
          post :duplicate
          delete :force_delete
          patch :restore
        end
        resources :venues do
          post :attach_image, on: :member
          resources :sections do
            get :seats, on: :member
            resources :event_seat_groups, path: 'groups' do
              post :assign_seats, on: :member
            end
            resources :event_ticket_seats, path: 'ticket-seats' do
              member do
                post :lock
                post :unlock
              end
            end
          end
        end
      end
    end

    # Business Matching Availability
    namespace :business_matching do
      post 'receive', to: 'callbacks#receive'
      post 'events/:event_id/report', to: 'bookings#generate_report'

      # Public booking creation route (authenticated users)
      post 'events/:event_id/bookings/public', to: 'bookings#public_create'

      scope 'events/:business_matching_event_id' do
        resources :availability, only: [:index]
        get 'availability/:date/slots', to: 'availability#show_slots'
        resources :bookings, only: %i[index create update] do
          collection do
            get :generate_report
          end
        end
      end

      scope 'events/:event_id' do
        resources :hosts, only: [:index] do
          get ':host_user_id/availability', to: 'hosts#show_availability', on: :collection
          post 'join', to: 'hosts#join', on: :collection
          post 'create_and_assign', to: 'hosts#create_and_assign', on: :collection
          delete 'remove', to: 'hosts#remove', on: :collection
        end
      end
    end

    # Event Leads (exhibitor lead capture — replaces visitor stamps)
    scope 'events/:event_id' do
      resources :event_leads, only: %i[index create update], path: 'event-leads'
    end
    post 'event-leads/scan', to: 'event_leads#scan'
    get 'event-leads/recent', to: 'event_leads#recent'

    # UNIFIED SCAN ENDPOINT (handles both tickets and visitors)
    # GET /v1/scan/recent_check_ins - Get recent check-ins for authorized events
    # PATCH /v1/scan/:public_id/check_in
    get 'scan/recent_check_ins', to: 'scan#recent_check_ins'
    patch 'scan/:public_id/check_in', to: 'scan#check_in'

    # GLOBAL VISITOR ACTIONS
    # PATCH /v1/visitors/:public_id/check_in
    resources :visitors, only: [] do
      patch ':public_id/check_in', to: 'visitors#global_check_in', on: :collection
      patch ':id/unscan', to: 'visitors#unscan', on: :collection
    end

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
    post 'imports/visitors', to: 'imports#visitors' # POST /v1/imports/visitors

    # 5b. TICKET EXPORTS (separate resource for export management)
    resources :ticket_exports, only: %i[index show create], path: 'tickets/exports' do
      # GET /v1/tickets/exports?event_id=1 - List all exports for an event
      # GET /v1/tickets/exports/:id - Download a specific export file
      # POST /v1/tickets/exports - Create new export (generates file)
    end

    # 6. TEAM MEMBERS MANAGEMENT
    resources :team_members, only: %i[index show create update destroy] do
      collection do
        get 'organizer/:organizer_id', to: 'team_members#organizer_members'
        get 'organizers', to: 'team_members#organizers'
      end
      member do
        patch :toggle_status
      end
    end

    resources :groups do
      resources :members, controller: 'group_members', only: %i[index create update destroy]
      resources :affiliates, controller: 'group_affiliates', only: %i[index create destroy]
    end

    # Vendor profile management (vendor-centric, not group-specific)
    resource :vendor_profile, only: %i[show update]

    # Payment details (bank account info for payees)
    resource :payment_detail, only: %i[show create update destroy] do
      get :me, on: :collection
    end

    # Vendor dashboard
    get 'vendor/dashboard', to: 'vendor_dashboard#index'

    # Contractor dashboard
    get 'contractor/dashboard', to: 'contractor_dashboard#index'

    resources :vendors, only: %i[index show create update destroy] do
      member do
        patch :toggle_status
        get :profile, to: 'vendor_profiles#show'
        patch :profile, to: 'vendor_profiles#update'
      end
    end

    resources :vouchers, only: %i[index show create update destroy]
    resources :voucher_redemptions, only: [:create]

    # 7. GLOBAL METRICS
    # Sponsorships
    resources :sponsors do
      collection do
        get :lookup
      end
    end

    resources :events do
      resources :event_sponsorship_tiers, only: %i[index create update destroy]
      resources :event_sponsorships, only: %i[index create show update destroy]
    end

    resources :event_sponsorships, only: [] do
      resources :event_sponsorship_payments, only: %i[index create update destroy]
      resources :event_sponsorship_attachments, only: %i[index create destroy]
      resources :event_sponsorship_items, only: %i[index create update destroy]
    end

    scope :metrics do
      get 'events_overview', to: 'analytics#events_overview'
      get 'summary',         to: 'analytics#summary'
      get 'total_tickets',            to: 'analytics#total_tickets'
      get 'total_scanned_tickets',    to: 'analytics#total_scanned_tickets'
      get 'total_unscanned_tickets',  to: 'analytics#total_unscanned_tickets'
      get 'total_amount_price',       to: 'analytics#total_amount_price'
    end

    # 7c. EVENT METRICS
    scope :events do
      scope ':event_id' do
        scope :metrics do
          get 'total_tickets',            to: 'event_analytics#total_tickets'
          get 'total_scanned_tickets',    to: 'event_analytics#total_scanned_tickets'
          get 'total_unscanned_tickets',  to: 'event_analytics#total_unscanned_tickets'
          get 'total_visitors',           to: 'event_analytics#total_visitors'
          get 'total_scanned_visitors',   to: 'event_analytics#total_scanned_visitors'
          get 'total_unscanned_visitors', to: 'event_analytics#total_unscanned_visitors'
          get 'total_amount_price',       to: 'event_analytics#total_amount_price'
          get 'mall_live_feed',           to: 'event_analytics#mall_live_feed'
          get 'time_series',              to: 'event_analytics#time_series'
          get 'hourly_breakdown_by_day',  to: 'event_analytics#hourly_breakdown_by_day'
        end
      end
    end

    # 8. API KEYS MANAGEMENT
    resources :api_keys, only: %i[index create destroy]

    # 9. GENERIC UPLOADS
    resources :uploads, only: [:create]

    # Exhibition Contractors (user accounts with exhibition_contractor role)
    resources :exhibition_contractors, only: %i[index show create update destroy] do
      collection do
        get :available
      end
      member do
        patch :toggle_status
        get :assigned_events
      end
    end

    # Exhibition Contractor Profiles (profile data only)
    resources :exhibition_contractor_profiles, only: %i[show update]

    resources :rentable_items
    resources :printing_services

    # REMOVED conflicting only: [] definitions
    resources :event_rentable_items, only: [] do
      resources :event_rentable_item_prices, controller: 'event_rentable_item_prices'
    end

    resources :exhibitor_booth_prices, only: [] do
      resources :price_tiers, controller: 'exhibitor_booth_price_tiers'
    end

    # --- RESOURCES CMS ---
    scope 'resources' do
      # Collection routes for the main Resources controller
      get 'public', to: 'resources#index_public', as: 'public_resources'
      get 'approval_index', to: 'resources#approval_index', as: 'approval_index_resources'
      get 'owner', to: 'resources#index_owner', as: 'owner_resources'

      # /v1/resources/permissions
      resources :permissions, controller: 'resources_permissions', except: %i[new edit], as: 'resources_permissions'

      # /v1/resources/topics
      resources :topics, controller: 'resources_topics', except: %i[new edit], as: 'resources_topics' do
        member do
          post :restore
          delete :force_destroy
        end
      end

      # /v1/resources/categories
      resources :categories, controller: 'resources_categories', except: %i[new edit], as: 'resources_categories' do
        member do
          post :restore
          delete :force_destroy
        end
      end

      # /v1/resources/media_types
      resources :media_types, controller: 'resources_media_types', except: %i[new edit], as: 'resources_media_types' do
        member do
          post :restore
          delete :force_destroy
        end
      end

      # /v1/resources/leads
      resources :leads, controller: 'resources_leads', only: %i[index show create], as: 'resources_leads' do
        get :metrics, on: :collection
      end

      # /v1/resources/permission_context/:id
      resources :permission_context, only: [:show], controller: 'permission_context'
    end

    # This is separate to avoid nesting under /resources
    # /v1/resources
    resources :resources, controller: 'resources', except: %i[new edit] do
      member do
        get :public, action: :show_public
        post :restore
        post :duplicate
        delete :force_destroy
        patch :approval
        post :increment_view
      end
    end

    resources :event_printing_services, only: [] do
      resources :event_printing_service_prices, controller: 'event_printing_service_prices'
    end

    resources :exhibitor_booth_prices, only: %i[update destroy]
    resources :exhibitor_zones, only: %i[update destroy]
  end
end
