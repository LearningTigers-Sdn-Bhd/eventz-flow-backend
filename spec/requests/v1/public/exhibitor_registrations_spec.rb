require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorRegistrations', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let!(:zone) { create(:exhibitor_zone, event: event, zone: 'zone_d', quota: 103) }
  let!(:booth_price) do
    create(
      :exhibitor_booth_price,
      event: event,
      exhibitor_zone: zone,
      booth_type: 'shell_scheme',
      label: 'Malaysian',
      price: 1500.00,
      quota: 30
    )
  end
  let(:alternate_booth_price) do
    create(
      :exhibitor_booth_price,
      event: event,
      exhibitor_zone: zone,
      booth_type: 'raw_space',
      label: 'International',
      price: 2500.00,
      quota: 30,
      conferences_included: true
    )
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_ic_upload' do
    it 'uploads an event-bound IC copy and returns a signed ID' do
      post "/v1/public/events/#{event.slug}/exhibitor_ic_upload",
           params: { file: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body).fetch('data')
      blob = ActiveStorage::Blob.find_signed!(data.fetch('signed_id'))
      expect(blob.metadata).to include('document_key' => 'exhibitor_ic_copy', 'event_id' => event.id)
    end

    it 'rejects unsupported files' do
      file = Tempfile.new(['ic', '.txt'])
      file.write('not an image')
      file.rewind

      post "/v1/public/events/#{event.slug}/exhibitor_ic_upload",
           params: { file: Rack::Test::UploadedFile.new(file.path, 'text/plain') }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('IC copy must be a JPEG, PNG, WebP, or PDF')
    ensure
      file.close!
    end
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_booth_prices' do
    it 'returns published event booth prices' do
      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']).to be_an(Array)
      expect(json['data'].first['label']).to eq('Malaysian')
      expect(json['data'].first['price'].to_f).to eq(1500.0)
      expect(json['data'].first['base_price'].to_f).to eq(1500.0)
      expect(json['data'].first['active_price_tier_label']).to be_nil
      expect(json['data'].first['zone']).to eq('zone_d')
      expect(json['data'].first['zone_quota']).to eq(103)
      expect(json['data'].first['zone_sold_count']).to eq(0)
      expect(json['data'].first['zone_remaining']).to eq(103)
      expect(json['data'].first['zone_available']).to eq(true)
      expect(json['data'].first['booth_price_quota']).to eq(30)
      expect(json['data'].first['booth_price_sold_count']).to eq(0)
      expect(json['data'].first['booth_price_remaining']).to eq(30)
      expect(json['data'].first['booth_price_available']).to eq(true)
    end

    it 'returns the active tier price when a booth tier is active' do
      create(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Early Bird',
        price: 1200,
        start_date: 1.day.ago,
        end_date: 1.day.from_now
      )

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].first['price'].to_f).to eq(1200.0)
      expect(json['data'].first['base_price'].to_f).to eq(1500.0)
      expect(json['data'].first['active_price_tier_label']).to eq('Early Bird')
    end

    it 'marks booth price unavailable when zone quota is full even if booth quota remains' do
      booth_price.update!(quota: 8)
      zone.update!(quota: 10)
      other_price = create(
        :exhibitor_booth_price,
        event: event,
        exhibitor_zone: zone,
        booth_type: 'shell_scheme',
        label: 'International',
        price: 1800.00,
        quota: nil
      )

      10.times do
        create(
          :exhibitor_kit,
          event_vendor: create(:exhibitor, event: event),
          exhibitor_booth_price: other_price,
          payment_status: :unpaid
        )
      end

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      malaysian = json['data'].find { |item| item['id'] == booth_price.id }
      expect(malaysian['zone_available']).to eq(false)
      expect(malaysian['booth_price_remaining']).to eq(8)
      expect(malaysian['booth_price_available']).to eq(false)
    end
  end

  describe 'POST /v1/public/events/:event_slug/register_exhibitor' do
    let(:email) { "amin-#{SecureRandom.hex(4)}@example.com" }

    let(:params) do
      {
        company_name: 'Acme Energy',
        company_address: 'Kota Kinabalu',
        booth_number: 'A-12',
        name_on_fascia: 'ACME ENERGY',
        pic_full_name: 'Amin Rahman',
        pic_position: 'Sales Manager',
        pic_contact_number: '0123456789',
        pic_email_address: email,
        country: 'Malaysia',
        product_category: 'Oil & Gas Equipment',
        payment_option: 'later',
        exhibitor_booth_price_id: booth_price.id,
        is_booth_manager: true,
        custom_fields_data: {
          preferred_booth_location: 'Hall A',
          other_services: ['Advertising Opportunities'],
          product_description: 'Industrial pumps and offshore safety equipment'
        }
      }
    end

    it 'creates user, exhibitor, kit, and stores profile fields' do
      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      end.to change(User, :count).by(1)
                                 .and change(Exhibitor, :count).by(1)
                                                               .and change(ExhibitorKit, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['price'].to_f).to eq(1500.0)
      expect(json['data']['payment_required']).to be(false)
      expect(json['data']['payment_option']).to eq('later')

      kit = ExhibitorKit.order(created_at: :desc).first
      user = User.find_by!(email: email)
      expect(kit.country).to eq('Malaysia')
      expect(kit.booth_number).to eq('A-12')
      expect(kit.name_on_fascia).to eq('ACME ENERGY')
      expect(kit.pic_position).to eq('Sales Manager')
      expect(kit.exhibitor_booth_price_id).to eq(booth_price.id)
      expect(kit.amount_paid.to_f).to eq(1500.0)
      expect(kit.payment_status).to eq('unpaid')
      expect(kit.custom_fields_data['preferred_booth_location']).to eq('Hall A')
      expect(kit.custom_fields_data['product_description']).to eq('Industrial pumps and offshore safety equipment')
      expect(kit.custom_fields_data['zone']).to eq('zone_d')
      expect(kit.custom_fields_data['is_booth_manager']).to eq(true)
      expect(user.authenticate('TempPass123!')).to eq(user)
      expect(user.vendor_profile.category).to eq('Oil & Gas Equipment')
      expect(user.vendor_profile.person_in_charge).to eq('Amin Rahman')
      expect(user.vendor_profile.address).to eq('Kota Kinabalu')
      expect(user.vendor_profile.description).to eq('Industrial pumps and offshore safety equipment')
    end

    it 'attaches a signed IC copy to the exhibitor kit' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Rails.root.join('spec/fixtures/files/test_image.png')),
        filename: 'ic-copy.png',
        content_type: 'image/png',
        metadata: { document_key: 'exhibitor_ic_copy', event_id: event.id }
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor",
           params: params.merge(ic_copy_signed_id: blob.signed_id)

      expect(response).to have_http_status(:created)
      expect(ExhibitorKit.order(created_at: :desc).first.ic_copy.blob).to eq(blob)
    end

    it 'rejects an IC copy uploaded for another event' do
      other_event = create(:event, status: :published, use_exhibitor_kit: true)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Rails.root.join('spec/fixtures/files/test_image.png')),
        filename: 'ic-copy.png',
        content_type: 'image/png',
        metadata: { document_key: 'exhibitor_ic_copy', event_id: other_event.id }
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor",
           params: params.merge(ic_copy_signed_id: blob.signed_id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('IC copy does not belong to this event')
    end

    it 'creates a booth manager team member and linked exhibitor ticket when requested' do
      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      end.to change(ExhibitorTeamMember, :count).by(1)

      expect(response).to have_http_status(:created)

      team_member = ExhibitorTeamMember.order(created_at: :desc).first
      expect(team_member.full_name).to eq('Amin Rahman')
      expect(team_member.email).to eq(email)
      expect(team_member.phone).to eq('0123456789')
      expect(team_member.attendee).to be_a(Ticket)
      expect(team_member.attendee.ticket_type.name).to eq('Exhibitor')
      expect(team_member.attendee.attendee_email).to eq(email)
      expect(team_member.attendee.custom_fields_data).not_to have_key('conferences_included')
    end

    it 'reuses and upgrades an existing conference-like ticket for Borneo Expo booth managers' do
      event.update!(slug: 'borneo-expo-2026')

      create(:ticket_type, event: event, name: 'Delegate Admission')
      combined_ticket_type = create(:ticket_type, event: event, name: 'Exhibitor & Conference Bundle')
      existing_ticket = create(
        :ticket,
        :paid,
        event: event,
        ticket_type: event.ticket_types.find_by!(name: 'Delegate Admission'),
        role: 'Custom Exhibitor Role',
        attendee_name: 'Amin Delegate',
        attendee_email: email,
        attendee_phone: '0123456789',
        status: :purchased
      )
      original_public_id = existing_ticket.public_id

      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      end.to change(ExhibitorTeamMember, :count).by(1)
         .and change(Ticket, :count).by(0)

      expect(response).to have_http_status(:created)

      team_member = ExhibitorTeamMember.order(created_at: :desc).first
      ticket = team_member.reload.attendee

      expect(ticket.id).to eq(existing_ticket.id)
      expect(ticket.public_id).to eq(original_public_id)
      expect(ticket.ticket_type).to eq(combined_ticket_type)
      expect(ticket.role).to eq('Custom Exhibitor Role')
      expect(ticket.attendee_email).to eq(email)
    end

    it 'does not create a duplicate booth manager team member for an existing registration' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor",
             params: params.merge(pic_email_address: "  #{email.upcase}  ")
      end.not_to change(ExhibitorTeamMember, :count)
    end

    it 'uses the active booth price tier for registration totals' do
      create(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Early Bird',
        price: 1200,
        start_date: 1.day.ago,
        end_date: 1.day.from_now
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['price'].to_f).to eq(1200.0)

      kit = ExhibitorKit.order(created_at: :desc).first
      expect(kit.amount_paid.to_f).to eq(1200.0)
    end

    it 'returns payment_required true when payment option is now' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params.merge(payment_option: 'now')

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['payment_required']).to be(true)
      expect(json['data']['payment_option']).to eq('now')
    end

    it 'does not overwrite an existing registration for the same email' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      existing_kit = ExhibitorKit.order(created_at: :desc).first

      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params.merge(company_name: 'Overwritten Co')
      end.to change(ExhibitorKit, :count).by(0)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['already_registered']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(existing_kit.id)
      expect(existing_kit.reload.company_name).to eq('Acme Energy')
    end

    it 'persists booth manager state when an existing registration is re-submitted with booth manager enabled' do
      existing_exhibitor = create(:exhibitor, event: event)
      existing_kit = existing_exhibitor.exhibitor_kit
      existing_kit.exhibitor_team_members.destroy_all
      existing_kit.update!(
        exhibitor_booth_price: booth_price,
        pic_email_address: email,
        custom_fields_data: { payment_option: 'later', zone: 'zone_d' }
      )

      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      end.to change(ExhibitorTeamMember, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(existing_kit.reload.custom_fields_data['is_booth_manager']).to eq(true)

      json = JSON.parse(response.body)
      expect(json['data']['already_registered']).to be(true)
      expect(json['data']['exhibitor_kit']['custom_fields_data']['is_booth_manager']).to eq(true)
    end

    it 'returns 422 when the selected zone quota is full' do
      booth_price.update!(quota: nil)
      zone.update!(quota: 1)
      create(
        :exhibitor_kit,
        event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price,
        payment_status: :unpaid
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Selected zone is sold out')
    end

    it 'returns 422 when the selected booth price quota is full' do
      booth_price.update!(quota: 1)
      create(
        :exhibitor_kit,
        event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price,
        payment_status: :unpaid
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Selected booth package is sold out')
    end
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_registration_status' do
    let!(:vendor) do
      create(
        :user,
        :vendor,
        email: 'amin@example.com',
        full_name: 'Amin Rahman'
      )
    end
    let!(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
    let!(:exhibitor_kit) do
      exhibitor.exhibitor_kit.tap do |kit|
        kit.update!(
          exhibitor_booth_price: booth_price,
          pic_email_address: 'amin@example.com',
          payment_status: :paid,
          custom_fields_data: { is_booth_manager: true, zone: 'zone_d' }
        )
      end
    end

    it 'returns existing registration status by email' do
      get "/v1/public/events/#{event.slug}/exhibitor_registration_status", params: { email: 'amin@example.com' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['has_registered']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(exhibitor_kit.id)
      expect(json['data']['payment_status']).to eq('paid')
      expect(json['data']['company_name']).to eq(exhibitor_kit.company_name)
      expect(json['data']['pic_email_address']).to eq('amin@example.com')
      expect(json['data']['exhibitor_booth_price_id']).to eq(booth_price.id)
      expect(json['data']['zone']).to eq('zone_d')
      expect(json['data']['is_booth_manager']).to eq(true)
      expect(json['data']['payment_proof_uploaded']).to eq(false)
      expect(json['data']['payment_proof_url']).to be_nil
    end

    it 'normalizes legacy booth manager values in serialized status responses' do
      exhibitor_kit.update!(custom_fields_data: exhibitor_kit.custom_fields_data.merge('is_booth_manager' => 'false'))

      get "/v1/public/events/#{event.slug}/exhibitor_registration_status", params: { email: 'amin@example.com' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['is_booth_manager']).to eq(false)
    end
  end

  describe 'PATCH /v1/public/events/:event_slug/register_exhibitor' do
    let(:email) { "amin-#{SecureRandom.hex(4)}@example.com" }
    let(:existing_exhibitor) { create(:exhibitor, event: event) }
    let!(:existing_kit) do
      create(
        :exhibitor_kit,
        event_vendor: existing_exhibitor,
        exhibitor_booth_price: booth_price,
        company_name: 'Acme Energy',
        booth_number: 'A-12',
        pic_email_address: email,
        custom_fields_data: { payment_option: 'later', zone: 'zone_d' }
      )
    end

    let(:update_params) do
      {
        exhibitor_kit_id: existing_kit.id,
        company_name: 'Updated Company',
        company_address: 'Kota Kinabalu',
        booth_number: 'B-01',
        name_on_fascia: 'UPDATED CO',
        pic_full_name: 'Amin Rahman',
        pic_position: 'Sales Manager',
        pic_contact_number: '0123456789',
        pic_email_address: email,
        country: 'Malaysia',
        product_category: 'Oil & Gas Equipment',
        payment_option: 'later',
        exhibitor_booth_price_id: alternate_booth_price.id,
        is_booth_manager: false,
        custom_fields_data: {
          preferred_booth_location: 'Hall B',
          other_services: ['Advertising Opportunities']
        }
      }
    end

    it 'updates existing registration details and booth package' do
      existing_team_member = existing_kit.exhibitor_team_members.first
      existing_team_member.attendee.update!(custom_fields_data: { legacy_note: 'keep me' })

      patch "/v1/public/events/#{event.slug}/register_exhibitor", params: update_params

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['already_registered']).to be(true)

      existing_kit.reload
      expect(existing_kit.exhibitor_booth_price_id).to eq(alternate_booth_price.id)
      expect(existing_kit.company_name).to eq('Updated Company')
      expect(existing_kit.booth_number).to eq('B-01')
      expect(existing_kit.amount_paid.to_f).to eq(2500.0)

      existing_team_member.update!(phone: '0198765432')
      existing_team_member.attendee.reload
      expect(existing_team_member.attendee.custom_fields_data['legacy_note']).to eq('keep me')
      expect(existing_team_member.attendee.custom_fields_data).not_to have_key('conferences_included')
    end

    it 'creates the booth manager team member on update when missing' do
      existing_kit.exhibitor_team_members.destroy_all

      expect do
        patch "/v1/public/events/#{event.slug}/register_exhibitor",
              params: update_params.merge(is_booth_manager: true)
      end.to change(ExhibitorTeamMember, :count).by(1)

      team_member = existing_kit.reload.exhibitor_team_members.order(:id).last
      expect(team_member.email).to eq(email)
      expect(team_member.attendee).to be_a(Ticket)
      expect(team_member.attendee.custom_fields_data).not_to have_key('conferences_included')
    end

    it 'does not duplicate the booth manager team member on update' do
      existing_kit.exhibitor_team_members.destroy_all
      create(:exhibitor_team_member,
             exhibitor_kit: existing_kit,
             full_name: 'Amin Rahman',
             email: email.upcase,
             phone: '0123456789')

      expect do
        patch "/v1/public/events/#{event.slug}/register_exhibitor",
              params: update_params.merge(is_booth_manager: true, pic_email_address: " #{email} ")
      end.not_to change(ExhibitorTeamMember, :count)
    end

    it 'preserves booth manager state when update requests false after the booth manager attendee already exists' do
      existing_kit.exhibitor_team_members.destroy_all
      existing_kit.update!(custom_fields_data: existing_kit.custom_fields_data.merge('is_booth_manager' => true))
      create(:exhibitor_team_member,
             exhibitor_kit: existing_kit,
             full_name: 'Amin Rahman',
             email: email,
             phone: '0123456789')

      patch "/v1/public/events/#{event.slug}/register_exhibitor", params: update_params.merge(is_booth_manager: false)

      expect(response).to have_http_status(:ok)
      expect(existing_kit.reload.custom_fields_data['is_booth_manager']).to eq(true)
      expect(existing_kit.exhibitor_team_members.count).to eq(1)

      get "/v1/public/events/#{event.slug}/exhibitor_registration_status", params: { exhibitor_kit_id: existing_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['is_booth_manager']).to eq(true)
      expect(json['data']['custom_fields_data']['is_booth_manager']).to eq(true)
    end

    it 'does not establish booth manager state from an unrelated team member when update requests false' do
      existing_kit.exhibitor_team_members.destroy_all
      existing_kit.update!(custom_fields_data: existing_kit.custom_fields_data.except('is_booth_manager'))
      create(:exhibitor_team_member,
             exhibitor_kit: existing_kit,
             full_name: 'Manual Team Member',
             email: 'manual@example.com',
             phone: '0123456789')

      patch "/v1/public/events/#{event.slug}/register_exhibitor", params: update_params.merge(is_booth_manager: false)

      expect(response).to have_http_status(:ok)
      expect(existing_kit.reload.custom_fields_data['is_booth_manager']).to eq(false)

      get "/v1/public/events/#{event.slug}/exhibitor_registration_status", params: { exhibitor_kit_id: existing_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['is_booth_manager']).to eq(false)
      expect(json['data']['custom_fields_data']['is_booth_manager']).to eq(false)
    end
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_payment_proof' do
    let!(:manual_zone) { create(:exhibitor_zone, event: event, zone: 'zone_a', quota: 10) }
    let!(:manual_booth_price) do
      create(
        :exhibitor_booth_price,
        event: event,
        exhibitor_zone: manual_zone,
        booth_type: 'raw_space',
        label: 'Diamond Package',
        price: 100_000.00
      )
    end
    let!(:manual_vendor) { create(:user, :vendor, email: 'manual@example.com') }
    let!(:manual_exhibitor) { create(:exhibitor, event: event, vendor: manual_vendor) }
    let!(:manual_kit) do
      create(
        :exhibitor_kit,
        event_vendor: manual_exhibitor,
        exhibitor_booth_price: manual_booth_price,
        pic_email_address: 'manual@example.com',
        custom_fields_data: { zone: 'zone_a' }
      )
    end

    it 'uploads payment proof for manual payment zones' do
      post "/v1/public/events/#{event.slug}/exhibitor_payment_proof",
           params: {
             exhibitor_kit_id: manual_kit.id,
             payment_proof: fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(manual_kit.id)
      expect(json['data']['payment_proof_uploaded']).to eq(true)
      expect(json['data']['payment_proof_url']).to be_present
      expect(manual_kit.reload.payment_proof).to be_attached
    end

    it 'rejects upload for non-manual payment zones' do
      non_manual_vendor = create(:user, :vendor, email: 'zoned@example.com')
      non_manual_exhibitor = create(:exhibitor, event: event, vendor: non_manual_vendor)
      non_manual_kit = create(
        :exhibitor_kit,
        event_vendor: non_manual_exhibitor,
        exhibitor_booth_price: booth_price,
        pic_email_address: 'zoned@example.com',
        custom_fields_data: { zone: 'zone_d' }
      )

      post "/v1/public/events/#{event.slug}/exhibitor_payment_proof",
           params: {
             exhibitor_kit_id: non_manual_kit.id,
             payment_proof: fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')
           }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Payment proof upload is only required for Zone A, B, or C')
    end

    it 'rejects payment proof larger than 20MB' do
      temp_file = Tempfile.new(['large-receipt', '.pdf'])
      temp_file.binmode
      temp_file.write('a' * (20.megabytes + 1))
      temp_file.rewind

      uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')

      post "/v1/public/events/#{event.slug}/exhibitor_payment_proof",
           params: {
             exhibitor_kit_id: manual_kit.id,
             payment_proof: uploaded_file
           }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Payment proof is too large (max 20MB)')
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  describe 'DELETE /v1/public/events/:event_slug/exhibitor_payment_proof' do
    let!(:manual_zone) { create(:exhibitor_zone, event: event, zone: 'zone_b', quota: 10) }
    let!(:manual_booth_price) do
      create(
        :exhibitor_booth_price,
        event: event,
        exhibitor_zone: manual_zone,
        booth_type: 'raw_space',
        label: 'Platinum Package',
        price: 75_000.00
      )
    end
    let!(:manual_vendor) { create(:user, :vendor, email: 'remove-proof@example.com') }
    let!(:manual_exhibitor) { create(:exhibitor, event: event, vendor: manual_vendor) }
    let!(:manual_kit) do
      create(
        :exhibitor_kit,
        event_vendor: manual_exhibitor,
        exhibitor_booth_price: manual_booth_price,
        pic_email_address: 'remove-proof@example.com',
        custom_fields_data: { zone: 'zone_b' }
      )
    end

    before do
      manual_kit.payment_proof.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
        filename: 'test_image.png',
        content_type: 'image/png'
      )
    end

    it 'removes uploaded payment proof' do
      delete "/v1/public/events/#{event.slug}/exhibitor_payment_proof", params: { exhibitor_kit_id: manual_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['payment_proof_uploaded']).to eq(false)
      expect(json['data']['payment_proof_url']).to be_nil
      expect(manual_kit.reload.payment_proof).not_to be_attached
    end
  end
end
