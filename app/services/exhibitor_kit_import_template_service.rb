require 'caxlsx'

# Generates the .xlsx template organizers fill in and re-upload via
# ExhibitorKitImportService. Two sheets:
#   1. Exhibitors - the rows to fill in
#   2. Reference  - read-only current booth price / zone / package combos
class ExhibitorKitImportTemplateService
  FIXED_HEADERS = [
    'Vendor Email', 'Vendor Name', 'Vendor Phone',
    'Company Name', 'Company Address',
    'PIC Name', 'PIC Contact', 'PIC Email',
    'Booth Type', 'Zone', 'Price Label', 'Package Name',
    'Booth Quantity', 'Amount Paid', 'Payment Status'
  ].freeze

  def self.export(event_id)
    new(event_id).export
  end

  def initialize(event_id)
    @event = Event.find(event_id)
  end

  def export
    package = Axlsx::Package.new(author: 'EventzFlow')
    # Lookup columns must be known before the Exhibitors sheet is built, since its
    # dropdown formulas reference the (not-yet-written) Reference sheet ranges by size.
    compute_reference_lookup_columns
    build_exhibitors_sheet(package)
    build_reference_sheet(package)

    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    file_path = exports_dir.join("exhibitor-import-template-#{@event.id}-#{timestamp}.xlsx")
    package.serialize(file_path.to_s)

    { file_path: file_path.to_s }
  end

  private

  # Sourced from the event's configured exhibitor_labels_data schema (Event Settings)
  # rather than scanning existing exhibitor_kits — a fresh event with zero exhibitors
  # booked yet still gets its custom columns, instead of only appearing once someone
  # has already registered with that field filled in.
  def custom_field_headers
    (@event.exhibitor_labels_data || {}).values
  end

  # Columns whose valid values live on the Reference sheet. Organizers kept mistyping
  # these (wrong zone for a booth type, stale price label) with no indication the
  # Reference sheet was the source of truth — hence the dropdown + comment + highlight.
  REFERENCE_COLUMNS = ['Booth Type', 'Zone', 'Price Label', 'Package Name'].freeze
  MAX_TEMPLATE_ROWS = 500

  # Same required set ExhibitorKitImportService rejects a row for missing — kept as
  # the single source of truth there; referenced here only to decide what to
  # highlight, so the two can't silently drift apart.
  def required_columns
    ExhibitorKitImportService::REQUIRED_HEADERS
  end

  def build_exhibitors_sheet(package)
    headers = FIXED_HEADERS + custom_field_headers
    reference_style = package.workbook.styles.add_style(bg_color: 'FFF9E6B7', b: true) # yellow: matches a Reference sheet list
    required_style = package.workbook.styles.add_style(bg_color: 'FFF8D7DA', b: true) # red-ish: required, no fixed list
    plain_style = package.workbook.styles.add_style(b: true)
    header_styles = headers.map do |h|
      if REFERENCE_COLUMNS.include?(h)
        reference_style
      elsif required_columns.include?(h)
        required_style
      else
        plain_style
      end
    end

    package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
      sheet.add_row(headers, style: header_styles)

      REFERENCE_COLUMNS.each { |column_name| add_reference_dropdown(sheet, headers, column_name) }
      add_payment_status_dropdown(sheet, headers)

      required_columns.each do |column_name|
        next if REFERENCE_COLUMNS.include?(column_name) || column_name == 'Payment Status' # already commented above

        col_index = headers.index(column_name)
        next unless col_index

        sheet.add_comment(
          ref: "#{Axlsx.col_ref(col_index)}1",
          author: 'EventzFlow',
          visible: false,
          text: 'Required — row is rejected if this is blank.'
        )
      end
    end
  end

  def add_reference_dropdown(sheet, headers, column_name)
    col_index = headers.index(column_name)
    return unless col_index

    col_letter = Axlsx.col_ref(col_index)
    required_note = required_columns.include?(column_name) ? ' Required — row is rejected if this is blank.' : ''
    sheet.add_comment(
      ref: "#{col_letter}1",
      author: 'EventzFlow',
      visible: false, # hover-only; caxlsx defaults to permanently expanded otherwise
      text: "Must match a value from the Reference sheet's #{column_name} lookup list (below the price table). " \
            "Mismatched combos are the most common reason a row fails to import.#{required_note}"
    )

    # No dropdown when there's nothing to choose from (e.g. an event with booth
    # prices but zero packages configured) — an empty range would produce an
    # invalid formula1 and corrupt the workbook for Excel.
    return if @reference_lookup_values.fetch(column_name).empty?

    sheet.add_data_validation("#{col_letter}2:#{col_letter}#{MAX_TEMPLATE_ROWS}", {
      type: :list,
      formula1: reference_lookup_range(column_name),
      showErrorMessage: true,
      errorTitle: 'Invalid value',
      error: "Value must match the Reference sheet's #{column_name} column."
    })
  end

  # Payment Status has a fixed, short enum (ExhibitorKit#payment_status) — small
  # enough to validate against an inline literal list instead of a sheet range.
  def add_payment_status_dropdown(sheet, headers)
    col_index = headers.index('Payment Status')
    return unless col_index

    col_letter = Axlsx.col_ref(col_index)
    statuses = ExhibitorKit.payment_statuses.keys
    sheet.add_comment(
      ref: "#{col_letter}1",
      author: 'EventzFlow',
      visible: false,
      text: "Required — must be one of: #{statuses.join(', ')}."
    )
    sheet.add_data_validation("#{col_letter}2:#{col_letter}#{MAX_TEMPLATE_ROWS}", {
      type: :list,
      formula1: "\"#{statuses.join(',')}\"",
      showErrorMessage: true,
      errorTitle: 'Invalid value',
      error: "Payment Status must be one of: #{statuses.join(', ')}."
    })
  end

  # Cell range (e.g. "Reference!$I$14:$I$16") backing the dropdown for a given
  # exhibitor-sheet column. Points at the deduped lookup block written below the
  # price table by write_reference_lookup_columns — row numbers computed up front
  # (compute_reference_lookup_columns) so both sheets agree without a second pass.
  def reference_lookup_range(column_name)
    col_letter = Axlsx.col_ref(REFERENCE_LOOKUP_START_COL + REFERENCE_COLUMNS.index(column_name))
    count = @reference_lookup_values.fetch(column_name).size
    first_row = @reference_lookup_first_row
    "Reference!$#{col_letter}$#{first_row}:$#{col_letter}$#{first_row + count - 1}"
  end

  # Deduped value lists for each REFERENCE_COLUMNS entry, written starting at column
  # A, stacked below the price table (not beside it) — keeps everything readable
  # top-to-bottom in one column instead of forcing a horizontal scroll. Computed
  # once and reused for both sheets so the Exhibitors sheet's dropdown ranges and
  # the Reference sheet's actual rows match.
  REFERENCE_LOOKUP_START_COL = 0 # column A (0-indexed)

  def compute_reference_lookup_columns
    prices = reference_prices
    @reference_lookup_values = {
      'Booth Type' => prices.map(&:booth_type).uniq,
      'Zone' => prices.filter_map(&:zone).uniq,
      'Price Label' => prices.map(&:label).uniq,
      'Package Name' => prices.flat_map { |p| p.exhibitor_packages.map(&:name) }.uniq
    }

    price_row_count = prices.sum { |p| p.exhibitor_packages.any? ? p.exhibitor_packages.size : 1 }
    # +1 header row, +1 spacer row, +1 lookup header row, +1 to land on the first value row
    @reference_lookup_first_row = price_row_count + 4
  end

  def reference_prices
    @reference_prices ||= @event.exhibitor_booth_prices
      .includes(:exhibitor_zone, :exhibitor_packages)
      .order(:booth_type, :label)
  end

  # Two separate remaining-quota columns because a booth price's own quota being
  # "Unlimited" does not mean it's actually bookable — its zone can still be capped
  # (and vice versa). Showing only one number was what made row 3's "quota
  # exceeded" import error look like a bug: the price-level column said Unlimited
  # while the zone was in fact full.
  def build_reference_sheet(package)
    prices = reference_prices
    booth_price_sold = sold_quantity_by_booth_price
    zone_sold = sold_quantity_by_zone
    styles = build_reference_styles(package.workbook.styles)

    package.workbook.add_worksheet(name: 'Reference') do |sheet|
      sheet.add_row([
        'Booth Type', 'Zone', 'Price Label', 'Current Price',
        'Remaining Quota (This Price)', 'Remaining Quota (Zone)', 'Package Name'
      ], style: Array.new(7, styles[:header]))

      prices.each_with_index do |price, i|
        price_remaining = remaining_quota(price.quota, booth_price_sold[price.id])
        zone_remaining = price.exhibitor_zone ? remaining_quota(price.exhibitor_zone.quota, zone_sold[price.exhibitor_zone_id]) : 'N/A'
        row_style = i.even? ? styles[:plain] : styles[:zebra]
        quota_style = ->(v) { row_style_for_quota(v, styles) }

        if price.exhibitor_packages.any?
          price.exhibitor_packages.each do |pkg|
            sheet.add_row(
              [price.booth_type, price.zone, price.label, price.current_price, price_remaining, zone_remaining, pkg.name],
              style: [row_style, row_style, row_style, row_style, quota_style.call(price_remaining), quota_style.call(zone_remaining), row_style]
            )
          end
        else
          sheet.add_row(
            [price.booth_type, price.zone, price.label, price.current_price, price_remaining, zone_remaining, nil],
            style: [row_style, row_style, row_style, row_style, quota_style.call(price_remaining), quota_style.call(zone_remaining), row_style]
          )
        end
      end

      # Uniform width sized for the widest block (the sample row's 15 columns),
      # since the price table, lookup lists, and sample row all now share column A.
      sheet.column_widths(*Array.new(FIXED_HEADERS.size, 18))
      sheet.sheet_view.pane do |pane|
        pane.state = :frozen
        pane.y_split = 1
        pane.top_left_cell = 'A2'
        pane.active_pane = :bottom_left
      end

      write_reference_lookup_columns(sheet, styles)
      write_sample_row(sheet, styles)
    end
  end

  # Bold white-on-navy headers, zebra-striped price rows, and quota cells colored
  # by bookability (green = open, red = full, grey italic = unlimited) — the plain
  # numbers-in-a-grid version was easy to misread under time pressure (see the
  # "Unlimited but zone is full" case build_reference_sheet already guards against).
  def build_reference_styles(workbook_styles)
    {
      header: workbook_styles.add_style(bg_color: 'FF1E3A5F', fg_color: 'FFFFFFFF', b: true, alignment: { horizontal: :center }),
      plain: workbook_styles.add_style(bg_color: 'FFFFFFFF'),
      zebra: workbook_styles.add_style(bg_color: 'FFF3F4F6'),
      quota_open: workbook_styles.add_style(fg_color: 'FF15803D', b: true),
      quota_full: workbook_styles.add_style(fg_color: 'FFB91C1C', b: true),
      quota_unlimited: workbook_styles.add_style(fg_color: 'FF6B7280', i: true),
      sample_title: workbook_styles.add_style(bg_color: 'FFDBEAFE', fg_color: 'FF1E3A5F', b: true),
      sample_value: workbook_styles.add_style(bg_color: 'FFEFF6FF')
    }
  end

  def row_style_for_quota(value, styles)
    case value
    when 'Unlimited', 'N/A' then styles[:quota_unlimited]
    when 0 then styles[:quota_full]
    else styles[:quota_open]
    end
  end

  # Appends the deduped Booth Type / Zone / Price Label / Package Name lists below
  # the price table (a blank spacer row, then a header row, then the values) so the
  # Exhibitors sheet's dropdown validations have something to point at. Plain
  # add_row calls only — row numbers match what compute_reference_lookup_columns
  # already promised the dropdown formulas.
  def write_reference_lookup_columns(sheet, styles)
    padding = Array.new(REFERENCE_LOOKUP_START_COL)
    max_rows = @reference_lookup_values.values.map(&:size).max.to_i

    sheet.add_row([])
    sheet.add_row(padding + REFERENCE_COLUMNS.map { |name| "#{name} (lookup)" },
      style: padding.map { nil } + Array.new(REFERENCE_COLUMNS.size, styles[:header]))
    (0...max_rows).each do |row_i|
      sheet.add_row(padding + REFERENCE_COLUMNS.map { |name| @reference_lookup_values.fetch(name)[row_i] })
    end
  end

  # A real, valid example row — placed on the read-only Reference sheet (never
  # touched by ExhibitorKitImportService, which only reads the Exhibitors sheet)
  # so there's zero risk of it accidentally getting imported. Appended as its own
  # block below the lookup lists (not beside them), so the sheet reads top-to-bottom
  # in column A instead of sprawling sideways.
  SAMPLE_START_COL = 0 # column A (0-indexed)

  def write_sample_row(sheet, styles)
    sample_price = reference_prices.first
    return unless sample_price # nothing configured yet — no realistic sample to show

    sample_package = sample_price.exhibitor_packages.first
    padding = Array.new(SAMPLE_START_COL)
    headers = FIXED_HEADERS

    sheet.add_row([]) # spacer, separating this block from the lookup lists above

    title_row_num = sheet.rows.size + 1
    title_row = padding + ["Sample row — copy this format into the Exhibitors sheet"] + Array.new(headers.size - 1)
    sheet.add_row(title_row, style: Array.new(headers.size + SAMPLE_START_COL, styles[:sample_title]))
    first_col = Axlsx.col_ref(SAMPLE_START_COL)
    last_col = Axlsx.col_ref(SAMPLE_START_COL + headers.size - 1)
    sheet.merge_cells("#{first_col}#{title_row_num}:#{last_col}#{title_row_num}")

    sheet.add_row(padding + headers, style: padding.map { nil } + Array.new(headers.size, styles[:header]))

    values = {
      'Vendor Email' => 'vendor@example.com',
      'Vendor Name' => 'Jane Vendor',
      'Vendor Phone' => '0123456789',
      'Company Name' => 'Example Sdn Bhd',
      'Company Address' => '1 Jalan Example, 88000 Kota Kinabalu',
      'PIC Name' => 'Jane Vendor',
      'PIC Contact' => '0123456789',
      'PIC Email' => 'jane@example.com',
      'Booth Type' => sample_price.booth_type,
      'Zone' => sample_price.zone,
      'Price Label' => sample_price.label,
      'Package Name' => sample_package&.name,
      'Booth Quantity' => 1,
      'Amount Paid' => sample_package&.price || sample_price.current_price,
      'Payment Status' => ExhibitorKit.payment_statuses.keys.first
    }
    sheet.add_row(padding + headers.map { |h| values[h] }, style: padding.map { nil } + Array.new(headers.size, styles[:sample_value]))
  end

  def remaining_quota(quota, sold)
    return 'Unlimited' if quota.nil?

    [quota - sold.to_i, 0].max
  end

  def sold_quantity_by_booth_price
    ExhibitorKit.joins(:event_vendor)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .group(:exhibitor_booth_price_id)
      .sum(:booth_quantity)
  end

  def sold_quantity_by_zone
    ExhibitorKit.joins(:event_vendor, :exhibitor_booth_price)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .group('exhibitor_booth_prices.exhibitor_zone_id')
      .sum(:booth_quantity)
  end
end
