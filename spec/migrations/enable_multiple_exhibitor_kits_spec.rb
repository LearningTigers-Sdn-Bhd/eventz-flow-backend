require 'rails_helper'
require Rails.root.join('db/migrate/20260727160000_enable_multiple_exhibitor_kits')

RSpec.describe EnableMultipleExhibitorKits do
  let(:migration) { described_class.new }

  it 'backfills booking state, price precedence, currency, and public IDs' do
    event = create(:event)
    booth_price = create(:exhibitor_booth_price, event: event, price: 1_500)
    kits = %i[unpaid paid waived sponsored].map do |status|
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event), payment_status: status)
    end
    kits[0].update_columns(amount_paid: 100, exhibitor_booth_price_id: booth_price.id)
    kits[1].update_columns(amount_paid: nil, exhibitor_booth_price_id: booth_price.id)
    kits[2].update_columns(amount_paid: nil, exhibitor_booth_price_id: nil)
    kits[3].update_columns(amount_paid: 300, exhibitor_booth_price_id: booth_price.id)

    migration.down
    migration.up
    ExhibitorKit.reset_column_information

    rows = ExhibitorKit.where(id: kits.map(&:id)).order(:id)
    expect(rows.pluck(:booking_status)).to eq(%w[active paid paid paid])
    expect(rows.pluck(:price_snapshot)).to eq([100, 1_500, 0, 300].map(&:to_d))
    expect(rows.pluck(:currency)).to all(eq('MYR'))
    expect(rows.pluck(:public_id)).to all(be_present)
    expect(rows.distinct.count(:public_id)).to eq(4)
  ensure
    unless migration.column_exists?(:exhibitor_kits, :public_id)
      migration.up
      ExhibitorKit.reset_column_information
    end
  end

  it 'enforces scoped non-NULL idempotency keys at the database layer' do
    exhibitor = create(:exhibitor)
    other_exhibitor = create(:exhibitor)
    attributes = {
      booth_type: 'shell_scheme', pic_full_name: 'Test User',
      pic_contact_number: '+60123456789', created_at: Time.current, updated_at: Time.current
    }

    ExhibitorKit.insert_all!([
      attributes.merge(event_vendor_id: exhibitor.id, idempotency_key: nil),
      attributes.merge(event_vendor_id: exhibitor.id, idempotency_key: nil),
      attributes.merge(event_vendor_id: exhibitor.id, idempotency_key: 'registration-1'),
      attributes.merge(event_vendor_id: other_exhibitor.id, idempotency_key: 'registration-1')
    ])

    expect do
      ExhibitorKit.insert_all!([attributes.merge(event_vendor_id: exhibitor.id, idempotency_key: 'registration-1')])
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
