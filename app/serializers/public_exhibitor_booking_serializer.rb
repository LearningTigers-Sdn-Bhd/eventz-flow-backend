class PublicExhibitorBookingSerializer
  def self.summary(kit)
    payment = kit.exhibitor_registration_payment
    {
      public_id: kit.public_id,
      booking_reference: kit.public_id,
      company_name: kit.company_name,
      booth_number: kit.booth_number,
      booth_label: kit.exhibitor_booth_price&.label,
      zone: kit.exhibitor_booth_price&.zone,
      exhibitor_package: kit.exhibitor_package && {
        id: kit.exhibitor_package.id,
        name: kit.exhibitor_package.name,
        price: kit.exhibitor_package.price,
        inclusions: kit.exhibitor_package.inclusions
      },
      amount: kit.price_snapshot,
      currency: kit.currency,
      payment_status: kit.payment_status,
      payment_proof_status: payment&.status || 'pending',
      payment_proof_uploaded: payment&.payment_proof&.attached? || false,
      payment_note: payment&.note,
      booking_status: kit.booking_status,
      reservation_expires_at: kit.reservation_expires_at,
      lock_version: kit.lock_version
    }
  end

  def self.detail(kit)
    summary(kit).merge(
      company_address: kit.company_address,
      name_on_fascia: kit.name_on_fascia,
      pic_full_name: kit.pic_full_name,
      pic_position: kit.pic_position,
      pic_contact_number: kit.pic_contact_number,
      pic_email_address: kit.pic_email_address,
      country: kit.country,
      exhibitor_booth_price_id: kit.exhibitor_booth_price_id,
      exhibitor_package_id: kit.exhibitor_package_id,
      booth_quantity: kit.booth_quantity,
      ic_copy_uploaded: kit.ic_copy.attached?,
      custom_fields_data: kit.custom_fields_data.except(PublicExhibitorBookingService::FINGERPRINT_KEY)
    )
  end
end
