require 'rails_helper'

RSpec.describe "V1::Public::Registrations", type: :request do
  let(:event) { create(:event, status: :published) }
  let!(:ticket_type) do
    create(
      :ticket_type,
      event: event,
      name: "General",
      price: 100.00,
      status: :published,
      hidden: false,
      custom_fields_data: {
        company_name: "text",
        job_title: "text"
      }
    )
  end

  describe "GET /v1/public/events/:event_slug/ticket_types" do
    it "returns available ticket types" do
      get "/v1/public/events/#{event.slug}/ticket_types"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']).to be_an(Array)
      expect(json['data'].first['name']).to eq("General")
      expect(json['data'].first['price'].to_f).to eq(100.0)
      expect(json['data'].first['custom_fields_data']['company_name']).to eq("text")
    end

    context "with active price tier" do
      before do
        create(:ticket_type_price_tier,
          ticket_type: ticket_type,
          label: "Early Bird",
          price: 80.00,
          starts_at: 1.day.ago,
          ends_at: 1.day.from_now
        )
      end

      it "returns the tier price" do
        get "/v1/public/events/#{event.slug}/ticket_types"

        json = JSON.parse(response.body)
        expect(json['data'].first['price'].to_f).to eq(80.0)
        expect(json['data'].first['current_tier']).to eq("Early Bird")
      end
    end
  end

  describe "POST /v1/public/events/:event_slug/register" do
    let(:valid_params) do
      {
        attendee_name: "John Doe",
        attendee_email: "john@example.com",
        attendee_phone: "0123456789",
        ticket_type_id: ticket_type.id,
        role: "delegate",
        custom_fields_data: {
          company: "Acme Energy",
          job_title: "Engineer",
          registration_kind: "member"
        }
      }
    end

    it "creates a new ticket" do
      expect {
        post "/v1/public/events/#{event.slug}/register", params: valid_params
      }.to change(Ticket, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['attendee_name']).to eq("John Doe")
      expect(json['data']['payment_status']).to eq("pending")
      expect(json['data']['role']).to eq("delegate")
      expect(json['data']['custom_fields_data']['company']).to eq("Acme Energy")
    end

    context "with free ticket type" do
      before { ticket_type.update!(price: 0) }

      it "sets payment_status to paid" do
        post "/v1/public/events/#{event.slug}/register", params: valid_params

        json = JSON.parse(response.body)
        expect(json['data']['payment_status']).to eq("paid")
      end
    end

    context "with missing required fields" do
      it "returns validation errors" do
        post "/v1/public/events/#{event.slug}/register", params: { ticket_type_id: ticket_type.id }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when event is not published" do
      before { event.update!(status: :draft) }

      it "returns an error" do
        post "/v1/public/events/#{event.slug}/register", params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['message']).to include("not open")
      end
    end
  end

  # =========================================================================
  # Form-scoped registration (form_slug filtering)
  # =========================================================================

  context "with registration form mapping" do
    let!(:conference_ticket) do
      create(:ticket_type, event: event, name: "Conference Pass", price: 200.00, status: :published, hidden: false)
    end
    let!(:visitor_ticket) do
      create(:ticket_type, event: event, name: "Visitor Pass", price: 0, status: :published, hidden: false)
    end

    let!(:conference_form) do
      form = create(:registration_form, event: event, name: "Conference", slug: "conference")
      create(
        :registration_form_ticket_type,
        registration_form: form,
        ticket_type: conference_ticket,
        registration_mode: :group,
        min_attendees: 3,
        max_attendees: 10,
      )
      form
    end
    let!(:visitor_form) do
      form = create(:registration_form, event: event, name: "Visitor", slug: "visitor")
      form.ticket_types << visitor_ticket
      form
    end

    describe "GET /v1/public/events/:event_slug/ticket_types?form_slug=conference" do
      it "returns only ticket types mapped to the conference form" do
        get "/v1/public/events/#{event.slug}/ticket_types", params: { form_slug: "conference" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        names = json['data'].map { |tt| tt['name'] }
        expect(names).to include("Conference Pass")
        expect(names).not_to include("Visitor Pass")

        conference_response = json['data'].find { |tt| tt['id'] == conference_ticket.id }
        expect(conference_response['registration_mode']).to eq('group')
        expect(conference_response['min_attendees']).to eq(3)
        expect(conference_response['max_attendees']).to eq(10)
      end

      it "returns 404 for unknown form slug" do
        get "/v1/public/events/#{event.slug}/ticket_types", params: { form_slug: "nonexistent" }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /v1/public/events/:event_slug/register with form_slug" do
      it "rejects ticket type not mapped to the specified form" do
        post "/v1/public/events/#{event.slug}/register", params: {
          form_slug: "visitor",
          ticket_type_id: conference_ticket.id,
          attendee_name: "Jane Doe",
          attendee_email: "jane@example.com",
          attendee_phone: "0123456789"
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['message']).to include("not allowed")
      end

      it "succeeds with valid form + ticket combination" do
        post "/v1/public/events/#{event.slug}/register", params: {
          form_slug: "visitor",
          ticket_type_id: visitor_ticket.id,
          attendee_name: "Jane Doe",
          attendee_email: "jane@example.com",
          attendee_phone: "0123456789"
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['attendee_name']).to eq("Jane Doe")
      end
    end
  end
end
