# Shared column/row builder for exhibitor kit registration reports (Excel + CSV) so
# both export formats always show the exact same data - one place to add/rename a column.
class ExhibitorKitReportRows
  HEADERS = [
    'Company Name', 'PIC Name', 'PIC Email', 'PIC Contact', 'PIC Position', 'Country',
    'Booth Number', 'Booth Type', 'Booth Pricing', 'Zone',
    'Unit Price', 'Booking Value', 'Amount Paid', 'Currency',
    'Payment Status', 'Booking Status', 'Booked At'
  ].freeze

  def self.for(kits)
    kits.map do |kit|
      [
        kit.company_name,
        kit.pic_full_name,
        kit.pic_email_address,
        kit.pic_contact_number,
        kit.pic_position,
        kit.country,
        kit.booth_number,
        kit.booth_type&.titleize,
        kit.exhibitor_booth_price&.label,
        kit.exhibitor_booth_price&.zone,
        kit.price_snapshot.to_f,
        kit.booking_value.to_f,
        kit.amount_paid.to_f,
        kit.currency,
        kit.payment_status.titleize,
        kit.booking_status.titleize,
        kit.created_at
      ]
    end
  end
end
