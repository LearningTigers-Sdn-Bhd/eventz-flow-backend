require 'rails_helper'

RSpec.describe "V1::LuckyDraw::Sessions", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" } }
  let!(:session1) { create(:lucky_draw_session, event: event, title: "Session 1") }

  describe "GET /v1/events/:event_id/lucky_draw/sessions" do
    it "returns all sessions with draw_styles" do
      get "/v1/events/#{event.id}/lucky_draw/sessions", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'][0]['title']).to eq("Session 1")
      expect(json_response['data'][0]).to have_key('draw_styles')
      expect(json_response['data'][0]['draw_styles']).to be_a(Hash)
    end
  end

  describe "POST /v1/events/:event_id/lucky_draw/sessions" do
    it "creates a session with draw_styles" do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: "New Session", draw_styles: { style: "wheel", theme: "wireframe" } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(LuckyDrawSession.count).to eq(2)
      expect(json_response['data']['title']).to eq("New Session")
      expect(json_response['data']['draw_styles']).to eq({ 'style' => 'wheel', 'theme' => 'wireframe' })
    end

    it "rejects invalid draw_styles structure" do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: "New Session", draw_styles: { style: "invalid", theme: "wireframe" } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /v1/events/:event_id/lucky_draw/sessions/:id" do
    it "returns the session with draw_styles" do
      get "/v1/events/#{event.id}/lucky_draw/sessions/#{session1.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['id']).to eq(session1.id)
      expect(json_response['data']).to have_key('draw_styles')
      expect(json_response['data']['draw_styles']).to be_a(Hash)
    end
  end

  describe "PATCH /v1/events/:event_id/lucky_draw/sessions/:id" do
    it "updates the session" do
      patch "/v1/events/#{event.id}/lucky_draw/sessions/#{session1.id}",
            params: { title: "Updated Title" },
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(session1.reload.title).to eq("Updated Title")
    end

    it "updates draw_styles" do
      patch "/v1/events/#{event.id}/lucky_draw/sessions/#{session1.id}",
            params: { draw_styles: { style: "box", theme: "colorful" } },
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['draw_styles']).to eq({ 'style' => 'box', 'theme' => 'colorful' })
      expect(session1.reload.draw_styles).to eq({ 'style' => 'box', 'theme' => 'colorful' })
    end
  end

  describe "DELETE /v1/events/:event_id/lucky_draw/sessions/:id" do
    it "deletes the session" do
      delete "/v1/events/#{event.id}/lucky_draw/sessions/#{session1.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(LuckyDrawSession.count).to eq(0)
    end
  end
end
