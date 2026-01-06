require 'rails_helper'

RSpec.describe "V1::EventExhibitionContractors", type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:api_key) { create(:api_key, user: org_owner) }
  let(:auth_header) { { 'Authorization' => api_key.raw_key } }

  let(:event) { create(:event) }
  let(:exhibition_contractor_profile) { create(:exhibition_contractor_profile) }

  describe "GET /v1/events/:event_id/event_exhibition_contractor" do
    context "when an event exhibition contractor is assigned" do
      let!(:assigned_exhibition_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: exhibition_contractor_profile) }

      context "with valid authorization" do
        before { get v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header }

        it "returns a successful response" do
          expect(response).to have_http_status(:ok)
        end

        it "returns the event exhibition contractor for the event" do
          expect(json_body['id']).to eq(assigned_exhibition_contractor.id)
        end
      end

      context "without authorization" do
        before { get v1_event_event_exhibition_contractor_path(event_id: event.id) }

        it "returns unauthorized" do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context "when no event exhibition contractor is assigned" do
      before { get v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header }

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns a message indicating no contractor assigned" do
        expect(json_body['message']).to eq("No exhibition contractor assigned to this event")
      end
    end
  end

  describe "POST /v1/events/:event_id/event_exhibition_contractor" do
    let(:new_exhibition_contractor_profile) { create(:exhibition_contractor_profile) }
    let(:valid_attributes) do
      {
        event_exhibition_contractor: {
          exhibition_contractor_profile_id: new_exhibition_contractor_profile.id
        }
      }
    end

    context "with valid authorization and valid attributes" do
      it "creates a new event exhibition contractor" do
        expect {
          post v1_event_event_exhibition_contractor_path(event_id: event.id), params: valid_attributes, headers: auth_header
        }.to change(EventExhibitionContractor, :count).by(1)
      end

      it "returns a created response" do
        post v1_event_event_exhibition_contractor_path(event_id: event.id), params: valid_attributes, headers: auth_header
        expect(response).to have_http_status(:created)
      end
    end

    context "with valid authorization and invalid attributes (e.g., duplicate event_id)" do
      let(:new_profile_for_duplicate) { create(:exhibition_contractor_profile) }
      let(:invalid_attributes) do
        {
          event_exhibition_contractor: {
            exhibition_contractor_profile_id: new_profile_for_duplicate.id
          }
        }
      end

      it "does not create a duplicate event exhibition contractor" do
        create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: create(:exhibition_contractor_profile))
        expect {
          post v1_event_event_exhibition_contractor_path(event_id: event.id), params: invalid_attributes, headers: auth_header
        }.to_not change(EventExhibitionContractor, :count)
      end

      it "returns unprocessable entity" do
        create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: create(:exhibition_contractor_profile))
        post v1_event_event_exhibition_contractor_path(event_id: event.id), params: invalid_attributes, headers: auth_header
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        post v1_event_event_exhibition_contractor_path(event_id: event.id), params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /v1/events/:event_id/event_exhibition_contractor" do
    let!(:event_exhibition_contractor_to_delete) { create(:event_exhibition_contractor, event: event) }

    context "with valid authorization" do
      it "deletes the event exhibition contractor" do
        expect {
          delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        }.to change(EventExhibitionContractor, :count).by(-1)
      end

      it "returns no content" do
        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        expect(response).to have_http_status(:no_content)
      end

      it "sets use_exhibitor_kit to false on the event" do
        event.update!(use_exhibitor_kit: true)
        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        expect(event.reload.use_exhibitor_kit).to be(false)
      end
    end

    context "when contractor has linked rentable items" do
      let(:contractor_user) { event_exhibition_contractor_to_delete.exhibition_contractor_profile.user }
      let!(:rentable_item1) { create(:rentable_item, user: contractor_user) }
      let!(:rentable_item2) { create(:rentable_item, user: contractor_user) }
      let!(:event_rentable_item1) { create(:event_rentable_item, event: event, rentable_item: rentable_item1) }
      let!(:event_rentable_item2) { create(:event_rentable_item, event: event, rentable_item: rentable_item2) }

      it "removes all linked rentable items from the event" do
        expect {
          delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        }.to change(EventRentableItem, :count).by(-2)
      end

      it "only removes items belonging to the contractor" do
        other_user = create(:user, :exhibition_contractor)
        other_item = create(:rentable_item, user: other_user)
        other_event_item = create(:event_rentable_item, event: event, rentable_item: other_item)

        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header

        expect(EventRentableItem.exists?(other_event_item.id)).to be(true)
      end
    end

    context "when contractor has linked printing services" do
      let(:contractor_user) { event_exhibition_contractor_to_delete.exhibition_contractor_profile.user }
      let!(:printing_service1) { create(:printing_service, user: contractor_user) }
      let!(:printing_service2) { create(:printing_service, user: contractor_user) }
      let!(:event_printing_service1) { create(:event_printing_service, event: event, printing_service: printing_service1) }
      let!(:event_printing_service2) { create(:event_printing_service, event: event, printing_service: printing_service2) }

      it "removes all linked printing services from the event" do
        expect {
          delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        }.to change(EventPrintingService, :count).by(-2)
      end

      it "only removes services belonging to the contractor" do
        other_user = create(:user, :exhibition_contractor)
        other_service = create(:printing_service, user: other_user)
        other_event_service = create(:event_printing_service, event: event, printing_service: other_service)

        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header

        expect(EventPrintingService.exists?(other_event_service.id)).to be(true)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        delete v1_event_event_exhibition_contractor_path(event_id: event.id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when contractor has existing transactions" do
      let(:contractor_user) { event_exhibition_contractor_to_delete.exhibition_contractor_profile.user }
      let!(:rentable_item) { create(:rentable_item, user: contractor_user) }
      let!(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }
      let(:exhibitor) { create(:exhibitor, event: event) }
      let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }
      let!(:exhibitor_kit_item) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item) }

      it "does not delete the contractor" do
        expect {
          delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        }.to_not change(EventExhibitionContractor, :count)
      end

      it "returns unprocessable entity with HAS_TRANSACTIONS code" do
        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body['code']).to eq('HAS_TRANSACTIONS')
      end

      it "returns transaction details in the response" do
        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        expect(json_body['details']['rentable_items_in_use']).to eq(1)
      end
    end

    context "when contractor has existing printing service transactions" do
      let(:contractor_user) { event_exhibition_contractor_to_delete.exhibition_contractor_profile.user }
      let!(:printing_service) { create(:printing_service, user: contractor_user) }
      let!(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }
      let(:exhibitor) { create(:exhibitor, event: event) }
      let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }
      let!(:exhibitor_kit_printing) { create(:exhibitor_kit_printing, exhibitor_kit: exhibitor_kit, printing_service: printing_service) }

      it "does not delete the contractor" do
        expect {
          delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        }.to_not change(EventExhibitionContractor, :count)
      end

      it "returns printing services in use count" do
        delete v1_event_event_exhibition_contractor_path(event_id: event.id), headers: auth_header
        expect(json_body['details']['printing_services_in_use']).to eq(1)
      end
    end
  end
end

def json_body
  JSON.parse(response.body)
end
