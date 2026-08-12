require 'swagger_helper'

RSpec.describe 'V1::ExhibitorKits', type: :request do
  describe 'GET /v1/events/:event_id/exhibitor_kits/:id/customs_declaration' do
    let(:admin_user) { create(:user, :org_owner) }
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event)) }

    it 'downloads the customs declaration for an authorized organizer' do
      kit.customs_declaration_form.attach(io: StringIO.new('declaration'), filename: 'customs.pdf',
        content_type: 'application/pdf')

      get "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}/customs_declaration", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('declaration')
      expect(response.headers['Content-Disposition']).to include('customs.pdf')
    end
  end

  describe 'GET /v1/events/:event_id/exhibitor_kits/:id booth link' do
    let(:admin_user) { create(:user, :org_owner) }
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let(:kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

    it 'returns the linked exhibitor booth id' do
      booth = create(:exhibitor_booth, event: event, exhibitor_kit: kit)

      get "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['exhibitor_booth_id']).to eq(booth.id)
    end

    it 'returns nil when no exhibitor booth is linked' do
      get "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('exhibitor_booth_id' => nil)
    end
  end

  describe 'GET /v1/events/:event_id/exhibitor_kits/export' do
    let(:admin_user) { create(:user, :org_owner) }
    let(:member_user) { create(:user, :member) }
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let!(:kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event)) }

    it 'downloads a multi-sheet Excel workbook for an authorized organizer' do
      get "/v1/events/#{event.id}/exhibitor_kits/export", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )
      expect(response.headers['Content-Disposition']).to include('.xlsx')

      tempfile = Tempfile.new(['export', '.xlsx'], binmode: true)
      tempfile.write(response.body)
      tempfile.flush
      workbook = Roo::Excelx.new(tempfile.path)
      expect(workbook.sheets).to eq(['Summary', 'Registered Exhibitor', 'Exhibitor Crew'])
      expect(workbook.sheet('Registered Exhibitor').cell(2, 1)).to eq(kit.company_name)
      expect(workbook.sheet('Exhibitor Crew').cell(2, 1)).to eq(kit.company_name)
      tempfile.close!
    end

    it 'downloads a CSV of registered exhibitor kits when format=csv' do
      get "/v1/events/#{event.id}/exhibitor_kits/export", params: { format: 'csv' },
                                                            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('.csv')

      rows = CSV.parse(response.body)
      expect(rows.first).to eq(ExhibitorKitReportRows::HEADERS)
      expect(rows.second.first).to eq(kit.company_name)
    end

    it 'includes booth pricing tiers with zero bookings in the Summary breakdown' do
      unbooked = create(:exhibitor_booth_price, event: event, label: 'Untouched Tier')

      get "/v1/events/#{event.id}/exhibitor_kits/export", headers: auth_headers(admin_user)

      tempfile = Tempfile.new(['export', '.xlsx'], binmode: true)
      tempfile.write(response.body)
      tempfile.flush
      workbook = Roo::Excelx.new(tempfile.path)
      summary = workbook.sheet('Summary')
      row = (1..summary.last_row).find { |r| summary.cell(r, 1) == unbooked.label }
      expect(row).to be_present
      expect(summary.cell(row, 3)).to eq(0) # Booked column
      tempfile.close!
    end

    it 'rejects users without event management access' do
      get "/v1/events/#{event.id}/exhibitor_kits/export", headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects export when exhibitor kits are not enabled for the event' do
      disabled_event = create(:event, use_exhibitor_kit: false)

      get "/v1/events/#{disabled_event.id}/exhibitor_kits/export", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  path '/v1/events/{event_id}/exhibitor_kits' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'

    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:event_id) { event.id }

    get('list exhibitor_kits') do
      tags 'Exhibitor Kits'
      produces 'application/json'
      security [{ bearerAuth: [] }]

      let(:admin_user) { create(:user, :org_owner) }
      let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
      # Use the one created with the user
      let!(:contractor_profile) do
        contractor_user.reload.exhibition_contractor_profile
      end
      let!(:event_contractor) do
        create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile)
      end

      let(:exhibitor_user) { create(:user, :exhibitor) }
      let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) } # Create exhibitor event_vendor
      let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) } # Create exhibitor kit

      response(200, 'successful') do
        context 'as an admin' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test!
        end

        context 'as a contractor assigned to the event' do
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test!
        end

        context 'as an exhibitor for the event' do
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end
      end # Closes response(200, 'successful')

      response(403, 'forbidden') do
        context 'as a regular user not assigned to the event' do
          let(:Authorization) { "Bearer #{jwt_token(create(:user))}" }
          run_test!
        end
      end
    end

    post('create exhibitor_kit') do
      tags 'Exhibitor Kits'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :exhibitor_kit, in: :body, schema: {
        type: :object,
        properties: {
          event_vendor_id: { type: :integer },
          booth_number: { type: :string },
          booth_type: { type: :string },
          name_on_fascia: { type: :string },
          company_name: { type: :string },
          company_address: { type: :string },
          pic_full_name: { type: :string },
          pic_contact_number: { type: :string },
          pic_email_address: { type: :string }
        },
        required: %w[event_vendor_id booth_number booth_type name_on_fascia company_name company_address pic_full_name
                     pic_contact_number pic_email_address]
      }

      let(:admin_user) { create(:user, :org_owner) }
      let(:exhibitor_user) { create(:user, :vendor) }
      let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) } # Ensure exhibitor exists
      let(:booth_price) { create(:exhibitor_booth_price, event: event, quota: 2, price: 100) }
      let(:exhibitor_kit_attributes) do
        {
          event_vendor_id: exhibitor.id,
          exhibitor_booth_price_id: booth_price.id,
          booth_quantity: 1,
          booth_number: 'A1',
          booth_type: 'shell_scheme',
          name_on_fascia: 'Test Company',
          company_name: 'Test Company Pte Ltd',
          company_address: '123 Test St',
          pic_full_name: 'John Doe',
          pic_contact_number: '12345678',
          pic_email_address: 'john@example.com'
        }
      end
      let(:exhibitor_kit) { { exhibitor_kit: exhibitor_kit_attributes } }

      response(201, 'created') do
        context 'as an exhibitor creating their own kit' do
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          let!(:existing_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

          run_test! do |response|
            expect(exhibitor.reload.exhibitor_kits.count).to eq(2)
            expect(JSON.parse(response.body)['id']).not_to eq(existing_kit.id)
          end
        end

        context 'as an admin creating a kit for an exhibitor' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'when use_exhibitor_kit is false for the event' do
          let(:event) { create(:event, use_exhibitor_kit: false) }
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end

        context 'as a contractor (cannot create exhibitor kits)' do
          let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
          # Use the one created with the user
          let!(:contractor_profile) do
            contractor_user.reload.exhibition_contractor_profile
          end
          let!(:event_contractor) do
            create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile)
          end
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test!
        end
      end

      response(404, 'event vendor belongs to another event') do
        let(:foreign_event) { create(:event, use_exhibitor_kit: true) }
        let(:foreign_exhibitor) { create(:exhibitor, event: foreign_event, vendor: exhibitor_user) }
        let(:exhibitor_kit) do
          { exhibitor_kit: exhibitor_kit_attributes.merge(event_vendor_id: foreign_exhibitor.id) }
        end
        let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/exhibitor_kits/{id}' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'
    parameter name: 'id', in: :path, type: :string, description: 'ID of the exhibitor kit'

    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:event_id) { event.id }
    let(:admin_user) { create(:user, :org_owner) }
    let(:exhibitor_user) { create(:user, :exhibitor) }
    let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) }
    let!(:exhibitor_kit_record) do
      create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid, booth_number: 'A1')
    end
    let(:id) { exhibitor_kit_record.id }

    get('show exhibitor_kit') do
      tags 'Exhibitor Kits'
      produces 'application/json'
      security [{ bearerAuth: [] }]

      response(404, 'not found for a foreign event') do
        let(:other_event) { create(:event, use_exhibitor_kit: true) }
        let(:other_exhibitor) { create(:exhibitor, event: other_event, vendor: create(:user, :vendor)) }
        let(:id) { create(:exhibitor_kit, event_vendor: other_exhibitor).id }
        let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }

        run_test!
      end
    end

    patch('update exhibitor_kit') do
      tags 'Exhibitor Kits'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :exhibitor_kit, in: :body, schema: {
        type: :object,
        properties: {
          booth_number: { type: :string },
          payment_status: { type: :string, enum: %w[unpaid paid waived sponsored] },
          company_name: { type: :string }
        }
      }

      response(200, 'successful') do
        context 'as an admin updating any field (e.g., booth_number)' do
          let(:exhibitor_kit) { { exhibitor_kit: { booth_number: 'B2', company_name: 'Admin Changed Co.' } } }
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['booth_number']).to eq('B2')
            expect(data['company_name']).to eq('Admin Changed Co.')
          end
        end

        context 'as an exhibitor adding and removing team members with contact details' do
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }

          it 'creates a linked ticket when a member is added' do
            patch "/v1/events/#{event_id}/exhibitor_kits/#{id}", params: {
              exhibitor_kit: {
                exhibitor_team_members_attributes: [
                  {
                    full_name: 'New Team Member',
                    email: 'team.member@example.com',
                    phone: '+60112233445'
                  }
                ]
              }
            }, headers: { 'Authorization' => "Bearer #{jwt_token(exhibitor_user)}" }

            expect(response).to have_http_status(:ok)

            data = JSON.parse(response.body)
            created_member = data['exhibitor_team_members'].find { |member| member['full_name'] == 'New Team Member' }

            expect(created_member['email']).to eq('team.member@example.com')
            expect(created_member['phone']).to eq('+60112233445')
            expect(created_member['attendee_type']).to eq('Ticket')
            expect(created_member['attendee_id']).to be_present

            ticket = Ticket.find(created_member['attendee_id'])
            expect(ticket.attendee_email).to eq('team.member@example.com')
            expect(ticket.role).to eq('Exhibitor')
          end

          it 'deletes the linked ticket when a member is removed' do
            member = create(
              :exhibitor_team_member,
              exhibitor_kit: exhibitor_kit_record,
              full_name: 'Existing Team Member',
              email: 'existing.team.member@example.com',
              phone: '+60119998877'
            )

            ticket_id = member.attendee_id

            expect(ticket_id).to be_present

            patch "/v1/events/#{event_id}/exhibitor_kits/#{id}", params: {
              exhibitor_kit: {
                exhibitor_team_members_attributes: [
                  {
                    id: member.id,
                    _destroy: true
                  }
                ]
              }
            }, headers: { 'Authorization' => "Bearer #{jwt_token(exhibitor_user)}" }

            expect(response).to have_http_status(:ok)
            expect(Ticket.unscoped.find_by(id: ticket_id)).to be_nil
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a contractor attempting to update payment status' do
          let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
          let(:contractor_profile) { contractor_user.reload.exhibition_contractor_profile }
          let!(:event_contractor) do
            create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile)
          end
          let(:exhibitor_kit) { { exhibitor_kit: { payment_status: 'paid' } } }
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }

          run_test!
        end

        context 'as an exhibitor updating their own fields (e.g., company_name)' do
          let(:exhibitor_kit) { { exhibitor_kit: { company_name: 'Updated Exhibitor Co.' } } } # Attempt to update
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test! do |response|
            expect(response).to have_http_status(:forbidden) # Expect 403 Forbidden
          end
        end

        context 'as an exhibitor attempting to update booth_number' do
          let(:exhibitor_kit) { { exhibitor_kit: { booth_number: 'A3' } } }
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end

        context 'as a contractor attempting to update an exhibitor-managed field (e.g., company_name)' do
          let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
          # Use the one created with the user
          let!(:contractor_profile) do
            contractor_user.reload.exhibition_contractor_profile
          end
          let!(:event_contractor) do
            create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile)
          end
          let(:exhibitor_kit) { { exhibitor_kit: { company_name: 'Contractor Changed Co.' } } }
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test! do |response|
            expect(response).to have_http_status(:forbidden) # Expect 403 Forbidden
          end
        end
      end

      response(404, 'not found for a foreign event') do
        let(:other_event) { create(:event, use_exhibitor_kit: true) }
        let(:other_exhibitor) { create(:exhibitor, event: other_event, vendor: create(:user, :vendor)) }
        let(:id) { create(:exhibitor_kit, event_vendor: other_exhibitor).id }
        let(:exhibitor_kit) { { exhibitor_kit: { booth_number: 'B2' } } }
        let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }

        run_test!
      end
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_kits booking rules' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:organizer) { create(:user, :organizer) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event, quota: 1, price: 100) }
    let(:headers) { { 'Authorization' => "Bearer #{jwt_token(organizer)}" } }
    let(:attributes) do
      attributes_for(:exhibitor_kit).slice(
        :booth_number, :name_on_fascia, :company_name, :company_address,
        :pic_full_name, :pic_contact_number, :pic_email_address
      ).merge(event_vendor_id: exhibitor.id, exhibitor_booth_price_id: booth_price.id, booth_quantity: 1)
    end

    it 'returns unprocessable content when capacity is exhausted' do
      create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_booth_price: booth_price,
        booth_quantity: 1, booking_status: :active)

      post "/v1/events/#{event.id}/exhibitor_kits", params: { exhibitor_kit: attributes }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(exhibitor.reload.exhibitor_kits.count).to eq(1)
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_kits with a voucher' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:organizer) { create(:user, :organizer) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 1000) }
    let!(:voucher) do
      create(:exhibitor_voucher, :fixed_amount, event: event, discount_value: 400)
    end
    let(:headers) { { 'Authorization' => "Bearer #{jwt_token(organizer)}" } }
    let(:attributes) do
      attributes_for(:exhibitor_kit).slice(
        :booth_number, :name_on_fascia, :company_name, :company_address,
        :pic_full_name, :pic_contact_number, :pic_email_address
      ).merge(
        event_vendor_id: exhibitor.id,
        exhibitor_booth_price_id: booth_price.id,
        voucher_code: voucher.code
      )
    end

    it 'prices the kit from the voucher and redeems it' do
      post "/v1/events/#{event.id}/exhibitor_kits",
        params: { exhibitor_kit: attributes },
        headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['price_snapshot'].to_f).to eq(600)
      expect(voucher.reload).to have_attributes(
        status: 'redeemed',
        redeemed_by_exhibitor_kit_id: response.parsed_body['id']
      )
    end

    it 'rejects an already-redeemed voucher code' do
      voucher.update!(
        status: :redeemed,
        redeemed_by_exhibitor_kit: create(:exhibitor_kit),
        redeemed_at: Time.current
      )

      post "/v1/events/#{event.id}/exhibitor_kits",
        params: { exhibitor_kit: attributes },
        headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to eq('Voucher code is invalid or already used')
    end
  end

  describe 'GET /v1/events/:event_id/exhibitor_kits/:id batch voucher display' do
    let(:admin_user) { create(:user, :org_owner) }
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let(:voucher) { create(:exhibitor_voucher, event: event, discount_value: 10) }
    let(:first_kit) do
      create(:exhibitor_kit, event_vendor: exhibitor,
        custom_fields_data: { 'booking_batch_id' => 'batch-1' })
    end
    let(:sibling_kit) do
      create(:exhibitor_kit, event_vendor: exhibitor,
        custom_fields_data: { 'booking_batch_id' => 'batch-1' })
    end

    it 'shows the shared voucher on every kit in the batch, not just the redeeming kit' do
      voucher.update!(status: :redeemed, redeemed_by_exhibitor_kit: first_kit, redeemed_at: Time.current)

      get "/v1/events/#{event.id}/exhibitor_kits/#{sibling_kit.id}", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['exhibitor_voucher_code']).to eq(voucher.code)
    end

    it 'returns nil when the kit has no batch or voucher' do
      solo_kit = create(:exhibitor_kit, event_vendor: exhibitor)

      get "/v1/events/#{event.id}/exhibitor_kits/#{solo_kit.id}", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['exhibitor_voucher_code']).to be_nil
    end
  end

  describe 'DELETE /v1/events/:event_id/exhibitor_kits/:id' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:organizer) { create(:user, :organizer) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let!(:exhibitor_kit) do
      create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid, booking_status: :active)
    end
    let!(:sibling_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }
    let(:headers) { { 'Authorization' => "Bearer #{jwt_token(organizer)}" } }

    it 'cancels only the requested unpaid active kit and preserves its vendor' do
      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(exhibitor_kit.reload).to be_booking_cancelled
      expect(ExhibitorKit.exists?(sibling_kit.id)).to be(true)
      expect(EventVendor.exists?(exhibitor.id)).to be(true)
    end

    it 'does not expose a kit through another event' do
      other_event = create(:event, use_exhibitor_kit: true)

      delete "/v1/events/#{other_event.id}/exhibitor_kits/#{exhibitor_kit.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(exhibitor_kit.reload).to be_booking_active
    end

    it 'rejects a paid kit without changing it' do
      exhibitor_kit.update!(payment_status: :paid)

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(exhibitor_kit.reload).to be_booking_active
    end

    it 'rejects a non-active kit without changing it' do
      exhibitor_kit.update!(booking_status: :expired)

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(exhibitor_kit.reload).to be_booking_expired
    end

    it 'rejects cancellation while a gateway order remains active' do
      create(:exhibitor_registration_payment, exhibitor_kit: exhibitor_kit,
        gateway_order_id: 'order_active', order_expires_at: 10.minutes.from_now)

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(exhibitor_kit.reload).to be_booking_active
    end

    it 'forbids an exhibitor from cancelling a kit' do
      exhibitor_user = exhibitor.vendor

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}",
        headers: { 'Authorization' => "Bearer #{jwt_token(exhibitor_user)}" }

      expect(response).to have_http_status(:forbidden)
      expect(exhibitor_kit.reload).to be_booking_active
    end
  end

  describe 'DELETE /v1/events/:event_id/exhibitor_kits/:id/force_delete' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:org_owner) { create(:user, :org_owner) }
    let(:organizer) { create(:user, :organizer) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let!(:exhibitor_kit) do
      create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :paid, booking_status: :active)
    end

    it 'lets an org owner hard-delete a paid, active kit without cancelling it first' do
      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}/force_delete",
        headers: { 'Authorization' => "Bearer #{jwt_token(org_owner)}" }

      expect(response).to have_http_status(:no_content)
      expect(ExhibitorKit.exists?(exhibitor_kit.id)).to be(false)
    end

    it 'removes an empty exhibitor assignment after hard-deleting its final kit' do
      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}/force_delete",
        headers: { 'Authorization' => "Bearer #{jwt_token(org_owner)}" }

      expect(response).to have_http_status(:no_content)
      expect(EventVendor.exists?(exhibitor.id)).to be(false)
    end

    it 'keeps the exhibitor assignment when another kit remains' do
      sibling_kit = create(:exhibitor_kit, event_vendor: exhibitor)

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}/force_delete",
        headers: { 'Authorization' => "Bearer #{jwt_token(org_owner)}" }

      expect(response).to have_http_status(:no_content)
      expect(ExhibitorKit.exists?(sibling_kit.id)).to be(true)
      expect(EventVendor.exists?(exhibitor.id)).to be(true)
    end

    it 'nullifies the audit link when hard-deleting a kit that redeemed a voucher' do
      voucher = create(:exhibitor_voucher, event: event, status: :redeemed,
        redeemed_by_exhibitor_kit: exhibitor_kit, redeemed_at: Time.current)

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}/force_delete",
        headers: { 'Authorization' => "Bearer #{jwt_token(org_owner)}" }

      expect(response).to have_http_status(:no_content)
      expect(voucher.reload).to have_attributes(
        status: 'redeemed',
        redeemed_by_exhibitor_kit_id: nil
      )
    end

    it 'forbids an organizer from using the force delete escape hatch' do
      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}/force_delete",
        headers: { 'Authorization' => "Bearer #{jwt_token(organizer)}" }

      expect(response).to have_http_status(:forbidden)
      expect(ExhibitorKit.exists?(exhibitor_kit.id)).to be(true)
    end

    it 'forbids an exhibitor from using the force delete escape hatch' do
      exhibitor_user = exhibitor.vendor

      delete "/v1/events/#{event.id}/exhibitor_kits/#{exhibitor_kit.id}/force_delete",
        headers: { 'Authorization' => "Bearer #{jwt_token(exhibitor_user)}" }

      expect(response).to have_http_status(:forbidden)
      expect(ExhibitorKit.exists?(exhibitor_kit.id)).to be(true)
    end
  end

  path '/v1/events/{event_id}/exhibitor_kits/import_template' do
    parameter name: :event_id, in: :path, type: :string, description: 'ID of the event'

    get('download exhibitor kit import template') do
      tags 'Exhibitor Kits'
      produces 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      security [{ bearerAuth: [] }]

      let(:event) { create(:event, use_exhibitor_kit: true) }
      let(:event_id) { event.id }

      response(200, 'template downloaded') do
        let(:organizer) { create(:user, :organizer) }
        let(:Authorization) { "Bearer #{jwt_token(organizer)}" }

        run_test!
      end

      response(403, 'forbidden') do
        let(:vendor) { create(:user, :vendor) }
        let(:Authorization) { "Bearer #{jwt_token(vendor)}" }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/exhibitor_kits/import' do
    parameter name: :event_id, in: :path, type: :string, description: 'ID of the event'

    post('import exhibitor kits from Excel') do
      tags 'Exhibitor Kits'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :file, in: :formData, type: :file, required: true,
                description: 'Excel workbook created from the exhibitor kit import template'
      parameter name: :dry_run, in: :query, type: :boolean, required: false,
                description: 'Validate rows without persisting bookings'

      let(:event) { create(:event, use_exhibitor_kit: true) }
      let(:event_id) { event.id }
      let(:organizer) { create(:user, :organizer) }
      let(:Authorization) { "Bearer #{jwt_token(organizer)}" }
      let(:zone) { create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10) }
      let!(:booth_price) do
        create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
          booth_type: 'Standard', label: 'Standard 3x3', price: 500, quota: 5)
      end
      let(:file) do
        require 'caxlsx'

        package = Axlsx::Package.new
        package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
          sheet.add_row(ExhibitorKitImportTemplateService::FIXED_HEADERS)
          sheet.add_row([
            'swagger-vendor@example.com', 'Swagger Vendor', '0123456789', 'Acme', 'Addr',
            'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid'
          ])
        end
        tempfile = Tempfile.new(['import', '.xlsx'])
        tempfile.binmode
        package.serialize(tempfile.path)
        tempfile.rewind
        Rack::Test::UploadedFile.new(tempfile.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      end

      response(200, 'import completed') do
        schema type: :object,
               properties: {
                 total: { type: :integer },
                 created: { type: :object },
                 skipped: { type: :object },
                 errors: { type: :object }
               },
               required: %w[total created skipped errors]

        run_test!
      end

      response(403, 'forbidden') do
        let(:vendor) { create(:user, :vendor) }
        let(:Authorization) { "Bearer #{jwt_token(vendor)}" }

        run_test!
      end

      response(422, 'file is missing') do
        let(:file) { nil }

        run_test!
      end
    end
  end
end
