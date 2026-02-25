require 'swagger_helper'

RSpec.describe 'V1::RegistrationForms', type: :request do
  # --- Setup Users ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user, :member) }

  # --- Setup Tokens ---
  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event ---
  let!(:event) do
    event = create(:event, title: "Test Event", payment_status: :paid, published: false)
    create(:event_assignment, role: :event_admin, event: event, user: organizer_user)
    event
  end

  # --- Setup Ticket Types ---
  let!(:ticket_type_1) { create(:ticket_type, event: event, name: "Conference Pass") }
  let!(:ticket_type_2) { create(:ticket_type, event: event, name: "VIP Pass") }
  let!(:ticket_type_3) { create(:ticket_type, event: event, name: "Golf Pass") }

  # --- Setup Registration Forms ---
  let!(:registration_form_1) do
    create(:registration_form, event: event, name: "Conference", slug: "conference", status: 0, position: 1)
  end

  let!(:registration_form_2) do
    create(:registration_form, event: event, name: "Visitor", slug: "visitor", status: 0, position: 2)
  end

  # --- Params ---
  let(:valid_create_params) do
    {
      registration_form: {
        name: 'Golf Tournament',
        slug: 'golf',
        description: 'Golf tournament registration',
        status: 0,
        position: 3,
        ticket_type_ids: [ticket_type_3.id],
        ticket_type_rules: [
          {
            ticket_type_id: ticket_type_3.id,
            registration_mode: 'single',
            min_attendees: 1,
            max_attendees: nil,
            custom_labels_data: [
              { "key" => "member_id", "label" => "Member ID" }
            ]
          }
        ],
        custom_labels_data: [
          { "key" => "company_name", "label" => "Company Name" },
          { "key" => "dietary_requirements", "label" => "Dietary Requirements" }
        ]
      }
    }
  end

  let(:update_params) do
    {
      registration_form: {
        name: 'Updated Conference',
        ticket_type_ids: [ticket_type_1.id, ticket_type_2.id],
        ticket_type_rules: [
          {
            ticket_type_id: ticket_type_1.id,
            registration_mode: 'single',
            min_attendees: 1,
            custom_labels_data: [
              { "key" => "member_id", "label" => "Member ID" }
            ]
          },
          {
            ticket_type_id: ticket_type_2.id,
            registration_mode: 'group',
            min_attendees: 2,
            max_attendees: 5,
            custom_labels_data: [
              { "key" => "invitation_code", "label" => "Invitation Code" }
            ]
          }
        ]
      }
    }
  end

  let(:invalid_params) do
    {
      registration_form: {
        name: '',
        slug: ''
      }
    }
  end

  # =========================================================================
  # GET /v1/events/:event_id/registration_forms (Index)
  # POST /v1/events/:event_id/registration_forms (Create)
  # =========================================================================

  path '/v1/events/{event_id}/registration_forms' do
    parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'

    # --- GET - Index ---
    get 'Lists all registration forms for an event' do
      tags 'Registration Forms'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'Registration forms returned' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }

        run_test! do
          json = JSON.parse(response.body)
          expect(json.length).to eq(2)
          names = json.map { |f| f['name'] }
          expect(names).to include('Conference', 'Visitor')
        end
      end

      response '403', 'Forbidden (Not authorized to view event)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        run_test!
      end

      response '401', 'Unauthorized (Missing Token)' do
        let(:Authorization) { 'Bearer ' }
        let(:event_id) { event.id }
        run_test!
      end
    end

    # --- POST - Create ---
    post 'Creates a new registration form' do
      tags 'Registration Forms'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :registration_form, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          slug: { type: :string },
          description: { type: :string },
          status: { type: :integer },
          position: { type: :integer },
          ticket_type_ids: { type: :array, items: { type: :integer } }
        },
        required: ['name', 'slug']
      }

      response '201', 'Registration form created with ticket mapping' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:registration_form) { valid_create_params }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Golf Tournament')
          expect(json['slug']).to eq('golf')
          expect(json['ticket_types'].length).to eq(1)
          expect(json['ticket_types'].first['id']).to eq(ticket_type_3.id)
          expect(json['ticket_types'].first['custom_labels_data']).to eq(
            [
              { "key" => "member_id", "label" => "Member ID" }
            ]
          )
          expect(json['custom_labels_data']).to eq(
            [
              { "key" => "company_name", "label" => "Company Name" },
              { "key" => "dietary_requirements", "label" => "Dietary Requirements" }
            ]
          )
        end
      end

      response '422', 'Unprocessable Entity (Invalid params)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:registration_form) { invalid_params }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
        end
      end

      response '422', 'Rejects ticket types from another event' do
        let(:other_event) { create(:event) }
        let(:other_ticket_type) { create(:ticket_type, event: other_event, name: "Other") }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:registration_form) do
          {
            registration_form: {
              name: 'Bad Form',
              slug: 'bad',
              ticket_type_ids: [other_ticket_type.id]
            }
          }
        end

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
        end
      end

      response '403', 'Forbidden (Member cannot create)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:registration_form) { valid_create_params }
        run_test!
      end
    end
  end

  # =========================================================================
  # PATCH /v1/events/:event_id/registration_forms/:id (Update)
  # DELETE /v1/events/:event_id/registration_forms/:id (Destroy)
  # =========================================================================

  path '/v1/events/{event_id}/registration_forms/{id}' do
    parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
    parameter name: :id, in: :path, type: :integer, description: 'Registration Form ID'

    # --- PATCH - Update ---
    patch 'Updates a registration form' do
      tags 'Registration Forms'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :registration_form, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          slug: { type: :string },
          description: { type: :string },
          status: { type: :integer },
          position: { type: :integer },
          ticket_type_ids: { type: :array, items: { type: :integer } }
        }
      }

      response '200', 'Update successful with ticket mapping sync' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { registration_form_1.id }
        let(:registration_form) { update_params }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Updated Conference')
          ticket_ids = json['ticket_types'].map { |t| t['id'] }
          expect(ticket_ids).to contain_exactly(ticket_type_1.id, ticket_type_2.id)

          ticket_type_1_payload = json['ticket_types'].find { |t| t['id'] == ticket_type_1.id }
          ticket_type_2_payload = json['ticket_types'].find { |t| t['id'] == ticket_type_2.id }

          expect(ticket_type_1_payload['custom_labels_data']).to eq(
            [
              { "key" => "member_id", "label" => "Member ID" }
            ]
          )
          expect(ticket_type_2_payload['custom_labels_data']).to eq(
            [
              { "key" => "invitation_code", "label" => "Invitation Code" }
            ]
          )
        end
      end

      response '403', 'Forbidden (Member cannot update)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:id) { registration_form_1.id }
        let(:registration_form) { update_params }
        run_test!
      end

      response '404', 'Registration form not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { 99999 }
        let(:registration_form) { update_params }
        run_test!
      end
    end

    # --- DELETE - Destroy ---
    delete 'Deletes a registration form' do
      tags 'Registration Forms'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'Deletion successful' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { registration_form_1.id }

        run_test! do
          expect(RegistrationForm.exists?(registration_form_1.id)).to be_falsey
        end
      end

      response '403', 'Forbidden (Member cannot delete)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:id) { registration_form_2.id }
        run_test!
      end

      response '404', 'Registration form not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end
