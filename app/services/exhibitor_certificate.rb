# One e-certificate per exhibitor company, however many booths or kits it booked.
# Wraps an Exhibitor with the values printed on the certificate and used for sending.
class ExhibitorCertificate
  attr_reader :exhibitor

  # Companies with at least one live, settled booking, ordered by company name.
  def self.for_event(event)
    ids = ExhibitorKit.certificate_eligible.joins(:event_vendor)
                      .where(event_vendors: { event_id: event.id }).distinct.pluck(:event_vendor_id)
    Exhibitor.where(id: ids).includes(:vendor, exhibitor_kits: :exhibitor_booths)
             .map { |exhibitor| new(exhibitor) }.sort_by { |cert| cert.company_name.to_s.downcase }
  end

  def initialize(exhibitor)
    @exhibitor = exhibitor
  end

  def kits
    @kits ||= exhibitor.exhibitor_kits.select(&:certificate_eligible?)
  end

  def eligible?
    kits.any?
  end

  def company_name
    kits.filter_map { |kit| kit.company_name.presence }.first || exhibitor.vendor&.full_name
  end

  def email
    kits.filter_map { |kit| kit.pic_email_address.presence }.first || exhibitor.vendor&.email
  end

  def booth_count
    kits.sum { |kit| [kit.booth_quantity.to_i, 1].max }
  end

  def booth_numbers
    kits.flat_map { |kit| [kit.booth_number, *kit.exhibitor_booths.map(&:number)] }
        .filter_map { |number| number.to_s.strip.presence }.uniq.join(', ')
  end
end
