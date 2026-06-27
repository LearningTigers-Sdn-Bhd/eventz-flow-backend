require 'prawn'

Prawn::Fonts::AFM.hide_m17n_warning = true

# Renders a single attendee's certificate as a PDF.
#
# The page is sized to the template's design canvas (canvas_width x canvas_height
# in px), so canvas pixels map 1:1 to PDF points and only the Y axis needs to be
# flipped (Prawn's origin is bottom-left; the designer's is top-left).
#
# Field coordinates (x, y, width, height, font_size) are in the same canvas-px
# space. See E_CERTIFICATE_DESIGN.md for the shared coordinate contract.
class CertificatePdfGenerator
  DEFAULT_COLOR = '000000'.freeze
  FONT_STYLES = %w[normal bold italic].freeze
  ALIGNMENTS = %w[left center right].freeze

  def initialize(template, ticket = nil, sample_name: nil)
    @template = template
    @ticket = ticket
    @sample_name = sample_name
  end

  # Renders many tickets into a single multi-page PDF (one certificate per
  # page). Used for bulk download. Returns nil when there are no tickets.
  def self.render_batch(template, tickets)
    raise ArgumentError, 'certificate template is required' if template.nil?

    tickets = tickets.to_a
    return nil if tickets.empty?

    cw = template.canvas_width.to_f
    ch = template.canvas_height.to_f
    cw = 1123.0 if cw <= 0
    ch = 794.0 if ch <= 0

    pdf = Prawn::Document.new(page_size: [cw, ch], margin: 0)
    tickets.each_with_index do |ticket, index|
      pdf.start_new_page(size: [cw, ch], margin: 0) if index.positive?
      new(template, ticket).draw_onto(pdf, cw, ch)
    end
    pdf.render
  end

  def render
    raise ArgumentError, 'certificate template is required' if @template.nil?

    cw = @template.canvas_width.to_f
    ch = @template.canvas_height.to_f
    cw = 1123.0 if cw <= 0
    ch = 794.0 if ch <= 0

    pdf = Prawn::Document.new(page_size: [cw, ch], margin: 0)
    draw_onto(pdf, cw, ch)
    pdf.render
  end

  # Draws this certificate onto an existing Prawn document page. Shared by
  # single render and batch render so layout logic lives in one place.
  def draw_onto(pdf, canvas_width, canvas_height)
    register_fonts(pdf)
    draw_background(pdf, canvas_width, canvas_height)
    fields.each { |field| draw_field(pdf, field, canvas_height) }
  end

  private

  def fields
    return [] unless @template.fields.is_a?(Array)

    @template.fields.map { |f| f.respond_to?(:with_indifferent_access) ? f.with_indifferent_access : f }
  end

  def draw_background(pdf, canvas_width, canvas_height)
    return unless @template.background_image.attached?

    @template.background_image.open do |file|
      pdf.image file.path, at: [0, canvas_height], width: canvas_width, height: canvas_height
    end
  rescue StandardError => e
    Rails.logger.error("Certificate background render failed: #{e.message}")
  end

  def draw_field(pdf, field, canvas_height)
    value = field_value(field)
    return if value.blank?

    pdf.fill_color(normalize_color(field[:color]))

    pdf.text_box value.to_s,
                 at: [field[:x].to_f, canvas_height - field[:y].to_f],
                 width: positive(field[:width], 200),
                 height: positive(field[:height], 60),
                 size: positive(field[:font_size], 24),
                 align: alignment(field[:align]),
                 valign: :center,
                 style: font_style(field[:font_style]),
                 overflow: :shrink_to_fit
  rescue StandardError => e
    Rails.logger.error("Certificate field render failed (#{field[:id]}): #{e.message}")
  end

  def field_value(field)
    case field[:type].to_s
    when 'attendee_name'
      @sample_name.presence || @ticket&.attendee_name
    when 'event_title'
      @template.event&.title
    when 'date'
      Date.current.strftime('%d %B %Y')
    when 'static_text'
      field[:static_value]
    end
  end

  def register_fonts(pdf)
    pdf.font_families.update(
      'Helvetica' => {
        normal: 'Helvetica',
        bold: 'Helvetica-Bold',
        italic: 'Helvetica-Oblique'
      }
    )
    pdf.font 'Helvetica'
  end

  def normalize_color(color)
    hex = color.to_s.delete('#').strip
    hex.match?(/\A[0-9a-fA-F]{6}\z/) ? hex.upcase : DEFAULT_COLOR
  end

  def alignment(value)
    ALIGNMENTS.include?(value.to_s) ? value.to_s.to_sym : :center
  end

  def font_style(value)
    FONT_STYLES.include?(value.to_s) ? value.to_s.to_sym : :normal
  end

  def positive(value, fallback)
    v = value.to_f
    v.positive? ? v : fallback
  end
end
