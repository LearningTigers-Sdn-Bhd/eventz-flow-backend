require "rails_helper"

RSpec.describe "V1::ExhibitorBoothPrices", type: :request do
  let(:event) { create(:event) }
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let!(:booth_price) { create(:exhibitor_booth_price, event: event, booth_type: "shell_scheme", label: "Malaysian") }

  describe "GET /v1/events/:event_id/exhibitor_booth_prices" do
    it "returns booth prices for org owner" do
      get "/v1/events/#{event.id}/exhibitor_booth_prices", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["id"]).to eq(booth_price.id)
    end

    it "returns empty collection for member" do
      get "/v1/events/#{event.id}/exhibitor_booth_prices", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe "POST /v1/events/:event_id/exhibitor_booth_prices" do
    let(:params) do
      {
        exhibitor_booth_price: {
          booth_type: "raw_space",
          label: "International",
          price: 3000.00,
        }
      }
    end

    it "creates booth price for org owner" do
      expect {
        post "/v1/events/#{event.id}/exhibitor_booth_prices", params: params, headers: auth_headers(admin_user)
      }.to change(ExhibitorBoothPrice, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "forbids member" do
      post "/v1/events/#{event.id}/exhibitor_booth_prices", params: params, headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /v1/exhibitor_booth_prices/:id" do
    it "updates booth price for org owner" do
      patch "/v1/exhibitor_booth_prices/#{booth_price.id}",
            params: { exhibitor_booth_price: { price: 1800.00 } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(booth_price.reload.price.to_f).to eq(1800.0)
    end
  end

  describe "DELETE /v1/exhibitor_booth_prices/:id" do
    it "deletes booth price for org owner" do
      expect {
        delete "/v1/exhibitor_booth_prices/#{booth_price.id}", headers: auth_headers(admin_user)
      }.to change(ExhibitorBoothPrice, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
