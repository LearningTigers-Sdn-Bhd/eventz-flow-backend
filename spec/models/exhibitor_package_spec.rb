require 'rails_helper'

RSpec.describe ExhibitorPackage, type: :model do
  let(:event) { create(:event) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event) }

  it 'is valid with a name, absolute price and same-event booth price' do
    package = build(:exhibitor_package, event: event, exhibitor_booth_price: booth_price,
      name: 'Package A | Standard Booth', price: 7000.00)

    expect(package).to be_valid
  end

  it 'requires a name' do
    package = build(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, name: nil)

    expect(package).not_to be_valid
    expect(package.errors[:name]).to be_present
  end

  it 'rejects a duplicate name within the same event' do
    create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, name: 'Package A')
    duplicate = build(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, name: 'Package A')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it 'allows the same name in a different event' do
    create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, name: 'Package A')
    other_event = create(:event)
    other = build(:exhibitor_package, event: other_event,
      exhibitor_booth_price: create(:exhibitor_booth_price, event: other_event), name: 'Package A')

    expect(other).to be_valid
  end

  it 'rejects a negative price' do
    package = build(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, price: -1)

    expect(package).not_to be_valid
    expect(package.errors[:price]).to be_present
  end

  it 'rejects a booth price belonging to another event' do
    foreign_price = create(:exhibitor_booth_price, event: create(:event))
    package = build(:exhibitor_package, event: event, exhibitor_booth_price: foreign_price)

    expect(package).not_to be_valid
    expect(package.errors[:exhibitor_booth_price_id]).to include('must belong to the same event')
  end

  it 'allows a nil quota' do
    expect(build(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: nil)).to be_valid
  end

  it 'rejects a negative quota' do
    expect(build(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: -1)).not_to be_valid
  end

  it 'reports whether it matches a submitted booth price id' do
    package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)

    expect(package.matches_booth_price?(booth_price.id)).to be true
    expect(package.matches_booth_price?(booth_price.id.to_s)).to be true
    expect(package.matches_booth_price?(booth_price.id + 1)).to be false
  end

  it 'refuses destroy while a booking references it' do
    package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)
    create(:exhibitor_kit, exhibitor_package: package)

    expect(package.destroy).to be false
    expect(package.errors[:base]).to be_present
  end

  it 'is destroyed with its booth price' do
    package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)

    booth_price.destroy

    expect(ExhibitorPackage.exists?(package.id)).to be false
  end
end
