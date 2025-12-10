# lucky_draw_swagger_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::LuckyDraw', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:staff_user) { create(:user, :staff_member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }

  # --- Setup Event ---
  let!(:organizer_event) do
    event = create(:event, title: 'Organizer Event', payment_status: :paid, use_ticket: false)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  let!(:ticket_event) do
    event = create(:event, title: 'Ticket Event', payment_status: :paid, use_ticket: true)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    event
  end

  let!(:session1) { create(:lucky_draw_session, event: organizer_event, title: "Session 1") }

  # --- Setup Test Data ---
  let!(:visitor1) { create(:visitor, event: organizer_event, full_name: 'Visitor One', email: 'visitor1@example.com') }
  let!(:visitor2) { create(:visitor, event: organizer_event, full_name: 'Visitor Two', email: 'visitor2@example.com') }
  let!(:ticket1) { create(:ticket, event: ticket_event, attendee_name: 'Ticket One') }
  let!(:ticket2) { create(:ticket, event: ticket_event, attendee_name: 'Ticket Two') }

  # ============================================================
  # Shared Schemas
  # ============================================================
  LUCKY_DRAW_SESSION_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      event_id: { type: :integer, example: 1 },
      title: { type: :string, example: 'Grand Lucky Draw' },
      draw_date: { type: :string, format: :date, nullable: true },
      logo: { type: :string, nullable: true },
      draw_styles: {
        type: :object,
        properties: {
          style: { type: :string, enum: ['wheel', 'slot', 'box'], example: 'wheel' },
          theme: { type: :string, nullable: true, example: 'wireframe' }
        }
      },
      wrapper_background: { type: :object },
      use_gifts: { type: :boolean, example: false },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id event_id title use_gifts]
  }.freeze

  GIFT_WINNER_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      gift_id: { type: :integer, example: 1 },
      ticket_id: { type: :integer, nullable: true, example: 1 },
      visitor_id: { type: :integer, nullable: true, example: 1 },
      participant_name: { type: :string, nullable: true, example: 'John Doe', description: 'Name of the participant (from ticket or visitor)' },
      drawn_at: { type: :string, format: :date_time },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id gift_id drawn_at]
  }.freeze

  GIFT_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      lucky_draw_session_id: { type: :integer, example: 1 },
      name: { type: :string, example: 'First Prize' },
      order: { type: :integer, example: 1 },
      winner_counts: { type: :integer, example: 3, description: 'Number of winners for this gift (must be > 0)' },
      winners: {
        type: :array,
        items: GIFT_WINNER_SCHEMA
      },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id lucky_draw_session_id name order winner_counts]
  }.freeze

  PARTICIPANT_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      name: { type: :string, example: 'John Doe' }
    },
    required: %w[id name]
  }.freeze

  INVALID_PARTICIPANT_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      lucky_draw_session_id: { type: :integer, example: 1 },
      participant: PARTICIPANT_SCHEMA,
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id lucky_draw_session_id participant]
  }.freeze

  # ============================================================
  # SESSIONS
  # ============================================================
  path '/v1/events/{event_id}/lucky_draw/sessions' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'

    get 'Lists all lucky draw sessions' do
      tags 'Lucky Draw Sessions'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      description 'Retrieves all lucky draw sessions for an event.'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Sessions retrieved successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Success' },
                 data: {
                   type: :array,
                   items: LUCKY_DRAW_SESSION_SCHEMA
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }

        run_test!
      end
    end

    post 'Creates a lucky draw session' do
      tags 'Lucky Draw Sessions'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      description 'Creates a new lucky draw session.'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :title, in: :formData, type: :string, required: true
      parameter name: :draw_date, in: :formData, type: :string, format: :date, required: false
      parameter name: :draw_style, in: :formData, type: :string, enum: ['wheel', 'slot', 'box'], required: false
      parameter name: :use_gifts, in: :formData, type: :boolean, required: false
      parameter name: :logo, in: :formData, type: :file, required: false

      response '201', 'Session created successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:title) { 'New Session' }
        let(:draw_style) { 'wheel' }
        let(:use_gifts) { false }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/lucky_draw/sessions/{id}' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'id', in: :path, type: :integer, required: true, description: 'Session ID'

    get 'Gets a specific session' do
      tags 'Lucky Draw Sessions'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Session retrieved successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }

        run_test!
      end
    end

    patch 'Updates a lucky draw session' do
      tags 'Lucky Draw Sessions'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :title, in: :formData, type: :string, required: false
      parameter name: :draw_date, in: :formData, type: :string, format: :date, required: false
      parameter name: :logo, in: :formData, type: :file, required: false
      parameter name: :remove_logo, in: :formData, type: :boolean, required: false

      response '200', 'Session updated successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:title) { 'Updated Title' }

        run_test!
      end
    end

    delete 'Deletes a lucky draw session' do
      tags 'Lucky Draw Sessions'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Session deleted successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/lucky_draw/sessions/{id}/background-manager' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'id', in: :path, type: :integer, required: true, description: 'Session ID'

    get 'Gets session background configuration' do
      tags 'Lucky Draw Sessions'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      description 'Retrieves the current background configuration (wrapper_background) for a session.'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Background configuration retrieved successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Success' },
                 data: {
                   type: :object,
                   properties: {
                     wrapper_background: {
                       type: :object,
                       properties: {
                         useImage: { type: :boolean, example: false, description: 'Whether to use image background' },
                         backgroundImgUrl: { type: :string, nullable: true, example: 'lucky_draw_session_backgrounds/bg-20240101_120000-abc123.jpg', description: 'Background image URL path' },
                         backgroundColor: { type: :string, nullable: true, example: '#ffffff', description: 'Background color (hex or rgb)' }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }

        before do
          session1.update(wrapper_background: { useImage: false, backgroundColor: '#ffffff' })
        end

        run_test!
      end
    end

    post 'Updates session background configuration' do
      tags 'Lucky Draw Sessions'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      description 'Updates the background configuration for a session. When useImage is true, upload a background image file (only required if no existing image is set). When useImage is false, provide a backgroundColor. Existing values are preserved when switching between modes (e.g., backgroundColor is preserved when switching to image mode, and backgroundImgUrl is preserved when switching to color mode).'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :useImage, in: :formData, type: :boolean, required: true, description: 'Whether to use image background (true) or color background (false)'
      parameter name: :backgroundImage, in: :formData, type: :file, required: false, description: 'Background image file (required when useImage is true and no existing image is set; optional if an existing image already exists)'
      parameter name: :backgroundColor, in: :formData, type: :string, required: false, description: 'Background color in hex or rgb format (required when useImage is false; optional when useImage is true to preserve existing color)'

      response '200', 'Background updated successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Background updated successfully' },
                 data: {
                   type: :object,
                   properties: {
                     wrapper_background: {
                       type: :object,
                       properties: {
                         useImage: { type: :boolean, example: false },
                         backgroundImgUrl: { type: :string, nullable: true, example: 'lucky_draw_session_backgrounds/test-image.png' },
                         backgroundColor: { type: :string, nullable: true, example: '#ff0000' }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { false }
        let(:backgroundColor) { '#ff0000' }

        run_test!
      end

      response '200', 'Background updated with image successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Background updated successfully' },
                 data: {
                   type: :object,
                   properties: {
                     wrapper_background: {
                       type: :object,
                       properties: {
                         useImage: { type: :boolean, example: true },
                         backgroundImgUrl: { type: :string, example: 'lucky_draw_session_backgrounds/bg-20240101_120000-abc123.jpg' },
                         backgroundColor: { type: :string, nullable: true }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { true }
        let(:backgroundImage) { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png') }

        before do
          test_image_path = Rails.root.join('spec', 'fixtures', 'test_image.png')
          unless File.exist?(test_image_path)
            FileUtils.mkdir_p(File.dirname(test_image_path))
            File.binwrite(test_image_path, "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\tpHYs\x00\x00\x0b\x13\x00\x00\x0b\x13\x01\x00\x9a\x9c\x18\x00\x00\x00\nIDATx\x9cc\xf8\x00\x00\x00\x01\x00\x01\x00\x00\x00\x00IEND\xaeB`\x82")
          end
        end

        run_test!
      end

      response '422', 'Validation failed - missing image file when no existing image' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { true }

        before do
          # Ensure no existing image is set
          session1.update(wrapper_background: { useImage: false, backgroundColor: '#ffffff' })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to include('Image file is required when useImage is true and no existing image is set')
        end
      end

      response '200', 'Keep existing image without uploading new file' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Background updated successfully' },
                 data: {
                   type: :object,
                   properties: {
                     wrapper_background: {
                       type: :object,
                       properties: {
                         useImage: { type: :boolean, example: true },
                         backgroundImgUrl: { type: :string, example: 'lucky_draw_session_backgrounds/existing-image.png' },
                         backgroundColor: { type: :string, nullable: true, example: '#ffffff' }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { true }

        before do
          # Set up session with existing image
          session1.update(wrapper_background: {
            useImage: true,
            backgroundImgUrl: "lucky_draw_session_backgrounds/existing-image.png",
            backgroundColor: '#ffffff'
          })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be true
          expect(data['data']['wrapper_background']['useImage']).to be true
          expect(data['data']['wrapper_background']['backgroundImgUrl']).to eq('lucky_draw_session_backgrounds/existing-image.png')
          expect(data['data']['wrapper_background']['backgroundColor']).to eq('#ffffff')
        end
      end

      response '200', 'Switching from color to image preserves backgroundColor' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Background updated successfully' },
                 data: {
                   type: :object,
                   properties: {
                     wrapper_background: {
                       type: :object,
                       properties: {
                         useImage: { type: :boolean, example: true },
                         backgroundImgUrl: { type: :string, example: 'lucky_draw_session_backgrounds/bg-20240101_120000-abc123.jpg' },
                         backgroundColor: { type: :string, nullable: true, example: '#ff0000' }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { true }
        let(:backgroundImage) { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png') }

        before do
          # Set up session with color background
          session1.update(wrapper_background: {
            useImage: false,
            backgroundImgUrl: nil,
            backgroundColor: '#ff0000'
          })
          test_image_path = Rails.root.join('spec', 'fixtures', 'test_image.png')
          unless File.exist?(test_image_path)
            FileUtils.mkdir_p(File.dirname(test_image_path))
            File.binwrite(test_image_path, "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\tpHYs\x00\x00\x0b\x13\x00\x00\x0b\x13\x01\x00\x9a\x9c\x18\x00\x00\x00\nIDATx\x9cc\xf8\x00\x00\x00\x01\x00\x01\x00\x00\x00\x00IEND\xaeB`\x82")
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be true
          expect(data['data']['wrapper_background']['useImage']).to be true
          expect(data['data']['wrapper_background']['backgroundImgUrl']).to be_present
          # backgroundColor should be preserved when switching to image mode
          expect(data['data']['wrapper_background']['backgroundColor']).to eq('#ff0000')
          session1.reload
          expect(session1.wrapper_background['useImage']).to be true
          expect(session1.wrapper_background['backgroundColor']).to eq('#ff0000')
          expect(session1.wrapper_background['backgroundImgUrl']).to be_present
        end
      end

      response '422', 'Validation failed - missing color' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { false }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to include('Background color is required')
        end
      end

      response '200', 'Switching from image to color preserves backgroundImgUrl' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Background updated successfully' },
                 data: {
                   type: :object,
                   properties: {
                     wrapper_background: {
                       type: :object,
                       properties: {
                         useImage: { type: :boolean, example: false },
                         backgroundImgUrl: { type: :string, nullable: true, example: 'lucky_draw_session_backgrounds/test-image.png' },
                         backgroundColor: { type: :string, nullable: true, example: '#00ff00' }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { session1.id }
        let(:useImage) { false }
        let(:backgroundColor) { '#00ff00' }

        before do
          # Set up session with image background
          session1.update(wrapper_background: {
            useImage: true,
            backgroundImgUrl: "lucky_draw_session_backgrounds/test-image.png",
            backgroundColor: nil
          })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be true
          expect(data['data']['wrapper_background']['useImage']).to be false
          expect(data['data']['wrapper_background']['backgroundColor']).to eq('#00ff00')
          # backgroundImgUrl should be preserved when switching to color mode
          expect(data['data']['wrapper_background']['backgroundImgUrl']).to eq('lucky_draw_session_backgrounds/test-image.png')

          session1.reload
          expect(session1.wrapper_background['useImage']).to be false
          expect(session1.wrapper_background['backgroundColor']).to eq('#00ff00')
          expect(session1.wrapper_background['backgroundImgUrl']).to eq('lucky_draw_session_backgrounds/test-image.png')
        end
      end
    end
  end

  # ============================================================
  # GIFTS
  # ============================================================
  path '/v1/events/{event_id}/lucky_draw/sessions/{session_id}/gifts' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'session_id', in: :path, type: :integer, required: true, description: 'Session ID'

    get 'Lists gifts for a session' do
      tags 'Lucky Draw Gifts'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Gifts retrieved successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }

        run_test!
      end
    end

    post 'Creates a gift' do
      tags 'Lucky Draw Gifts'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :gift, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          order: { type: :integer },
          winner_counts: { type: :integer }
        },
        required: ['name']
      }

      response '201', 'Gift created successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }
        let(:gift) { { name: 'New Gift' } }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/lucky_draw/sessions/{session_id}/gifts/{id}' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'session_id', in: :path, type: :integer, required: true, description: 'Session ID'
    parameter name: 'id', in: :path, type: :integer, required: true, description: 'Gift ID'

    put 'Updates a gift' do
      tags 'Lucky Draw Gifts'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :gift, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          order: { type: :integer },
          winner_counts: { type: :integer }
        }
      }

      response '200', 'Gift updated successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }
        let!(:gift_record) { create(:gift, lucky_draw_session: session1, name: 'Old Name') }
        let(:id) { gift_record.id }
        let(:gift) { { name: 'New Name' } }

        run_test!
      end
    end

    delete 'Deletes a gift' do
      tags 'Lucky Draw Gifts'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '204', 'Gift deleted successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }
        let!(:gift_record) { create(:gift, lucky_draw_session: session1) }
        let(:id) { gift_record.id }

        run_test!
      end
    end
  end

  # ============================================================
  # WINNERS
  # ============================================================
  path '/v1/events/{event_id}/lucky_draw/sessions/{session_id}/gifts/{gift_id}/winners' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'session_id', in: :path, type: :integer, required: true, description: 'Session ID'
    parameter name: 'gift_id', in: :path, type: :integer, required: true, description: 'Gift ID'

    post 'Creates a winner' do
      tags 'Lucky Draw Winners'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :winner, in: :body, required: true, schema: {
        type: :object,
        properties: {
          ticket_id: { type: :integer, nullable: true },
          visitor_id: { type: :integer, nullable: true }
        }
      }

      response '201', 'Winner created successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }
        let!(:gift) { create(:gift, lucky_draw_session: session1, winner_counts: 5) }
        let(:gift_id) { gift.id }
        let(:winner) { { visitor_id: visitor1.id } }

        run_test!
      end
    end
  end

  # ============================================================
  # PARTICIPANTS & INVALID
  # ============================================================
  path '/v1/events/{event_id}/lucky_draw/sessions/{session_id}/participants' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'session_id', in: :path, type: :integer, required: true, description: 'Session ID'

    get 'Lists participants' do
      tags 'Lucky Draw Participants'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Participants retrieved successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/lucky_draw/sessions/{session_id}/invalid_participants' do
    parameter name: 'event_id', in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: 'session_id', in: :path, type: :integer, required: true, description: 'Session ID'

    get 'Lists invalid participants' do
      tags 'Lucky Draw Invalid Participants'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'Invalid participants retrieved successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }

        run_test!
      end
    end

    post 'Creates invalid participant' do
      tags 'Lucky Draw Invalid Participants'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :invalid_participant, in: :body, required: true, schema: {
        type: :object,
        properties: {
          ticket_id: { type: :integer, nullable: true },
          visitor_id: { type: :integer, nullable: true }
        }
      }

      response '201', 'Invalid participant created' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:session_id) { session1.id }
        let(:invalid_participant) { { visitor_id: visitor1.id } }

        run_test!
      end
    end
  end
end
