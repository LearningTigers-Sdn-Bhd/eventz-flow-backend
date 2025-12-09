# spec/requests/v1/vendors_spec.rb
require 'swagger_helper'

RSpec.describe 'Vendors Management', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  VENDOR_ERROR_SCHEMA = {
    type: :object,
    properties: {
      error: { type: :string, example: 'Forbidden' },
      message: { type: :string, example: 'Only organizers can create vendors.' }
    },
    required: %w[error message]
  }.freeze

  VENDOR_USER_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer },
      email: { type: :string },
      full_name: { type: :string },
      phone: { type: :string, nullable: true },
      role: { type: :string, example: 'vendor' },
      status: { type: :string }
    },
    required: %w[id email full_name role status]
  }.freeze

  # ============================================================
  # Setup
  # ============================================================
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:auth_header_organizer) { "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" }
  let(:auth_header_member) { "Bearer #{JwtService.generate_tokens(member)[:access_token]}" }

  # ============================================================
  # POST /v1/vendors
  # ============================================================
  path '/v1/vendors' do
    post 'Creates a new vendor user' do
      tags 'Vendors'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          vendor: {
            type: :object,
            properties: {
              full_name: { type: :string, example: 'John Doe' },
              email: { type: :string, example: 'vendor@example.com' },
              phone: { type: :string, nullable: true, example: '+1234567890' },
              password: { type: :string, example: 'securepassword' },
              password_confirmation: { type: :string, example: 'securepassword' }
            },
            required: %w[full_name password password_confirmation]
          }
        },
        required: ['vendor']
      }

      let(:Authorization) { auth_header_organizer }

      response '201', 'Vendor created successfully' do
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: 'vendor@example.com',
              phone: '+1234567890',
              password: 'securepassword123',
              password_confirmation: 'securepassword123'
            }
          }
        end

        schema VENDOR_USER_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('vendor@example.com')
          expect(data['full_name']).to eq('John Doe')
          expect(data['role']).to eq('vendor')
          expect(data['status']).to eq('active')

          # Verify vendor user was created
          vendor_user = User.find_by(email: 'vendor@example.com')
          expect(vendor_user).to be_present
          expect(vendor_user.role).to eq('vendor')
        end
      end

      response '422', 'Validation error - password mismatch' do
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: 'vendor@example.com',
              password: 'securepassword123',
              password_confirmation: 'differentpassword'
            }
          }
        end

        schema type: :object,
          properties: {
            error: { type: :string },
            errors: { type: :array, items: { type: :string } }
          }

        run_test!
      end

      response '403', 'Forbidden for non-organizer' do
        let(:Authorization) { auth_header_member }
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: 'vendor@example.com',
              password: 'securepassword123',
              password_confirmation: 'securepassword123'
            }
          }
        end

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end
    end
  end
end
