require 'roo'

class VisitorExcelService
  # Import visitors from Excel file
  # @param file [ActionDispatch::Http::UploadedFile] The uploaded Excel file
  # @param dry_run [Boolean] If true, do not persist changes; return a report only
  # @param full [Boolean] If true, include full record data in response
  # @param no_label [Boolean] If true, map custom fields to sequential "Label N" keys
  # @return [Hash] { created: {count, data}, updated: {count, data}, skipped: {count, data}, duplicates_in_file: {count, data}, errors: {count, data} }
  def self.import(file, dry_run: false, full: false, no_label: false)
    # Reset cache at start of each import to avoid stale data
    @visitors_cache = {}

    results = {
      created: { count: 0, data: [] },
      updated: { count: 0, data: [] },
      skipped: { count: 0, data: [] },
      duplicates_in_file: { count: 0, data: [] },
      errors: { count: 0, data: [] }
    }

    begin
      xlsx = Roo::Spreadsheet.open(file.path)
      sheet = xlsx.sheet(0)

      # Read header row
      header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col)&.to_s&.strip }

      # Fixed column positions
      fixed_columns = {
        full_name: 1,
        email: 2,
        phone: 3,
        gender: 4,
        age: 5,
        role: 6,
        event_title: 7
      }

      # Identify custom label columns (all columns after event_title)
      label_columns = {}
      if sheet.last_column > 7
        (8..sheet.last_column).each do |col_idx|
          label_display_name = header_row[col_idx - 1]
          label_columns[col_idx] = label_display_name if label_display_name.present?
        end
      end

      # Build labels schema from headers
      labels_schema = {}
      label_columns.each_with_index do |(_col_idx, display_name), index|
        key = no_label ? "Label #{index + 1}" : machine_key_for(display_name)
        labels_schema[key] = display_name
      end

      # First pass: collect candidates and detect duplicates within file
      candidates = {}
      (2..sheet.last_row).each do |row_num|
        begin
          row_data = extract_row_data(sheet, row_num, fixed_columns, label_columns, no_label)
          next if row_data.nil?

          # Skip empty rows
          if empty_row?(row_data)
            results[:skipped][:count] += 1
            results[:skipped][:data] << build_record_data(nil, row_data, full) if full
            next
          end

          # Validate required fields
          if row_data[:full_name].blank? || row_data[:event_title].blank?
            results[:skipped][:count] += 1
            results[:skipped][:data] << build_record_data(nil, row_data, full) if full
            next
          end

          # Build unique key for duplicate detection
          key = build_candidate_key(row_data[:event_title], row_data[:full_name])

          # Keep the most complete row
          existing_candidate = candidates[key]
          if existing_candidate.nil? || row_completeness_score(row_data) > row_completeness_score(existing_candidate[:attrs])
            candidates[key] = { attrs: row_data, row_num: row_num }
          else
            results[:duplicates_in_file][:count] += 1
            results[:duplicates_in_file][:data] << build_record_data(nil, row_data, full) if full
          end
        rescue StandardError => e
          results[:errors][:count] += 1
          results[:errors][:data] << "Row #{row_num}: #{e.message}"
        end
      end

      # Group candidates by event and process
      events_cache = {}
      candidates.each_value do |entry|
        attrs = entry[:attrs]
        event_title = attrs[:event_title]

        # Find or create event
        event = events_cache[event_title] ||= find_or_create_event(event_title, labels_schema, no_label, dry_run)

        # Load existing visitors lookup for this event (cached per event)
        visitors_lookup = load_existing_visitors(event)

        # Find existing visitor using smart matching (email > phone > name)
        existing = find_existing_visitor(attrs, visitors_lookup)

        if existing
          process_existing_visitor(existing, attrs, event, results, dry_run, full)
        else
          create_new_visitor(attrs, event, results, dry_run, full)
        end
      end

    rescue StandardError => e
      results[:errors][:count] += 1
      results[:errors][:data] << "File processing error: #{e.message}"
    end

    results
  end

  private

  # Extract data from a single row
  def self.extract_row_data(sheet, row_num, fixed_columns, label_columns, no_label)
    full_name = titleize_name(sheet.cell(row_num, fixed_columns[:full_name]))
    email = normalize_email(sheet.cell(row_num, fixed_columns[:email]))
    phone = normalize_phone(sheet.cell(row_num, fixed_columns[:phone]))
    gender = sheet.cell(row_num, fixed_columns[:gender])&.to_s&.strip&.downcase
    age = parse_age(sheet.cell(row_num, fixed_columns[:age]))
    role = sheet.cell(row_num, fixed_columns[:role])&.to_s&.strip
    event_title = sheet.cell(row_num, fixed_columns[:event_title])&.to_s&.strip

    # Read custom fields
    custom_fields_data = {}
    label_columns.each_with_index do |(col_idx, display_name), index|
      value = sheet.cell(row_num, col_idx)&.to_s&.strip
      key = no_label ? "Label #{index + 1}" : machine_key_for(display_name)
      custom_fields_data[key] = value.presence || ''
    end

    {
      full_name: full_name,
      email: email,
      phone: phone,
      gender: gender,
      age: age,
      role: role,
      event_title: event_title,
      custom_fields_data: custom_fields_data
    }
  end

  # Find or create event with labels schema
  def self.find_or_create_event(event_title, labels_schema, no_label, dry_run)
    event = Event.find_by(title: event_title)

    if event.nil? && !dry_run
      event = Event.create!(
        title: event_title,
        status: :draft,
        start_date: 10.days.from_now,
        end_date: 20.days.from_now,
        visibility: true,
        labels_data: labels_schema.presence || {}
      )
    elsif event.nil? && dry_run
      # Return a mock event for dry run
      return OpenStruct.new(id: nil, title: event_title, labels_data: labels_schema, visitors: [])
    end

    # Update labels_data if needed
    if event && labels_schema.present? && !dry_run
      update_event_labels(event, labels_schema, no_label)
    end

    event
  end

  # Update event labels schema
  def self.update_event_labels(event, labels_schema, no_label)
    existing_labels = event.labels_data || {}
    import_style = no_label ? :labelN : :header
    existing_style = existing_labels.keys.any? { |k| k.to_s.match?(/^Label \d+$/) } ? :labelN : :header

    merged_labels = if existing_style != import_style
      labels_schema
    elsif import_style == :labelN
      merge_label_n_schema(existing_labels, labels_schema)
    else
      existing_labels.merge(labels_schema)
    end

    if event.labels_data != merged_labels
      event.update!(labels_data: merged_labels)
    end
  end

  # Load existing visitors into multiple lookup hashes for smart duplicate detection
  def self.load_existing_visitors(event)
    return { by_name: {}, by_email: {}, by_phone: {} } if event.is_a?(OpenStruct) # dry run mock

    @visitors_cache ||= {}
    @visitors_cache[event.id] ||= begin
      visitors = event.visitors.to_a
      {
        by_name: visitors.index_by { |v| normalize_name_key(v.full_name) },
        by_email: visitors.select { |v| v.email.present? }.index_by { |v| v.email.downcase },
        by_phone: visitors.select { |v| v.phone.present? }.index_by { |v| normalize_phone(v.phone) }
      }
    end
  end

  # Find existing visitor using smart matching:
  # 1. Email match (most reliable) - if emails match, same person
  # 2. Phone match (reliable) - if phones match, same person
  # 3. Name match - if names match AND no conflicting identifiers
  #    "Conflicting" = both have email but different, or both have phone but different
  def self.find_existing_visitor(attrs, lookup)
    # Priority 1: Exact email match
    if attrs[:email].present?
      existing = lookup[:by_email][attrs[:email].downcase]
      return existing if existing
    end

    # Priority 2: Exact phone match
    if attrs[:phone].present?
      existing = lookup[:by_phone][normalize_phone(attrs[:phone])]
      return existing if existing
    end

    # Priority 3: Name match with conflict check
    normalized_name = normalize_name_key(attrs[:full_name])
    existing_by_name = lookup[:by_name][normalized_name]

    if existing_by_name
      # Check for conflicting identifiers
      email_conflict = attrs[:email].present? && existing_by_name.email.present? &&
                       attrs[:email].downcase != existing_by_name.email.downcase
      phone_conflict = attrs[:phone].present? && existing_by_name.phone.present? &&
                       normalize_phone(attrs[:phone]) != normalize_phone(existing_by_name.phone)

      # Match if no conflicts (same person with incomplete data on one side)
      return existing_by_name unless email_conflict || phone_conflict
    end

    nil
  end

  # Process an existing visitor (update if more complete or has changes)
  def self.process_existing_visitor(existing, attrs, event, results, dry_run, full)
    existing_score = visitor_completeness_score(existing)
    new_score = row_completeness_score(attrs)
    changed_fields = detect_changes(existing, attrs)
    merged_custom = merge_custom_fields(existing.custom_fields_data, attrs[:custom_fields_data], event.labels_data)
    custom_fields_changed = merged_custom != (existing.custom_fields_data || {})

    # Update if: more complete data OR same completeness but has actual changes
    if new_score > existing_score || (new_score == existing_score && changed_fields.any?)
      unless dry_run
        update_attrs = {
          full_name: attrs[:full_name],
          email: attrs[:email].presence || existing.email,
          phone: attrs[:phone].presence || existing.phone,
          gender: attrs[:gender].presence || existing.gender,
          age: attrs[:age].presence || existing.age,
          role: attrs[:role].presence || existing.role,
          custom_fields_data: merged_custom
        }
        existing.update!(update_attrs)
      end

      results[:updated][:count] += 1
      results[:updated][:data] << build_record_data(existing, attrs, full, changed_fields)
    elsif custom_fields_changed
      # Less complete but custom_fields changed - only update custom_fields
      existing.update!(custom_fields_data: merged_custom) unless dry_run
      results[:updated][:count] += 1
      results[:updated][:data] << build_record_data(existing, attrs, full, ['custom_fields_data'])
    else
      # No changes at all - skip
      results[:skipped][:count] += 1
      results[:skipped][:data] << build_record_data(existing, attrs, full) if full
    end
  end

  # Create a new visitor
  def self.create_new_visitor(attrs, event, results, dry_run, full)
    visitor = nil

    unless dry_run
      merged_custom = merge_custom_fields({}, attrs[:custom_fields_data], event.labels_data)

      visitor = Visitor.create!(
        event: event,
        full_name: attrs[:full_name],
        email: attrs[:email],
        phone: attrs[:phone],
        gender: attrs[:gender],
        age: attrs[:age],
        role: attrs[:role],
        custom_fields_data: merged_custom
      )
    end

    results[:created][:count] += 1
    results[:created][:data] << build_record_data(visitor, attrs, true) # Always include data for created
  end

  # Merge custom fields with event labels schema
  def self.merge_custom_fields(existing_fields, new_fields, labels_data)
    base_keys = preferred_label_keys(labels_data)
    base = base_keys.index_with { |_k| '' }

    merged = base.merge(existing_fields.to_h).merge(new_fields.to_h)
    sanitize_custom_fields(merged, labels_data)
  end

  # Detect what fields changed
  def self.detect_changes(existing, attrs)
    changes = []
    changes << 'full_name' if attrs[:full_name].present? && attrs[:full_name] != existing.full_name
    changes << 'email' if attrs[:email].present? && attrs[:email] != existing.email
    changes << 'phone' if attrs[:phone].present? && attrs[:phone] != existing.phone
    changes << 'gender' if attrs[:gender].present? && attrs[:gender] != existing.gender
    changes << 'age' if attrs[:age].present? && attrs[:age] != existing.age
    changes << 'role' if attrs[:role].present? && attrs[:role] != existing.role
    changes << 'custom_fields_data' if attrs[:custom_fields_data] != (existing.custom_fields_data || {})
    changes
  end

  # Build record data for response
  def self.build_record_data(visitor, attrs, full, changed_fields = nil)
    data = {
      model: 'Visitor',
      id: visitor&.id&.to_s,
      full_name: attrs[:full_name],
      email: attrs[:email],
      phone: attrs[:phone],
      gender: attrs[:gender],
      age: attrs[:age],
      role: attrs[:role],
      event_title: attrs[:event_title]
    }

    data[:changed_fields] = changed_fields if changed_fields.present?
    data.merge!(attrs[:custom_fields_data]) if full && attrs[:custom_fields_data].present?

    data
  end

  # Build candidate key for duplicate detection
  def self.build_candidate_key(event_title, full_name)
    [
      "evt:#{event_title.to_s.downcase.strip}",
      "name:#{normalize_name_key(full_name)}"
    ].join('|')
  end

  # Normalization helpers
  # Normalize name for duplicate detection: remove all spaces, lowercase
  # This treats "Test Visitor", "Testvisitor", "test visitor" as the same
  def self.normalize_name_key(value)
    key = value.to_s.strip.gsub(/\s+/, '').downcase
    key.presence
  end

  def self.normalize_email(value)
    key = value.to_s.strip.downcase
    key.presence
  end

  def self.normalize_phone(value)
    digits = value.to_s.gsub(/\D+/, '')
    digits.presence
  end

  def self.titleize_name(value)
    s = value.to_s.strip
    return nil if s.empty?
    s.split(/\s+/).map { |w| w.downcase.capitalize }.join(' ')
  end

  def self.parse_age(value)
    return nil if value.nil?
    age = value.to_s.strip.to_i
    age > 0 ? age : nil
  end

  def self.machine_key_for(display_name)
    s = display_name.to_s.downcase
    s = s.gsub(/[^a-z0-9]+/, '_')
    s = s.gsub(/_{2,}/, '_')
    s = s.gsub(/^_|_$/, '')
    s
  end

  def self.empty_row?(row_data)
    [
      row_data[:full_name],
      row_data[:email],
      row_data[:phone],
      row_data[:gender],
      row_data[:age],
      row_data[:role],
      row_data[:event_title]
    ].all? { |v| v.nil? || v.to_s.strip.empty? } &&
      row_data[:custom_fields_data].values.all? { |v| v.nil? || v.to_s.strip.empty? }
  end

  def self.row_completeness_score(attrs)
    score = 0
    score += 1 if attrs[:full_name].present?
    score += 1 if attrs[:email].present?
    score += 1 if attrs[:phone].present?
    score += 1 if attrs[:gender].present?
    score += 1 if attrs[:age].present?
    score += 1 if attrs[:role].present?
    score += attrs[:custom_fields_data].values.count(&:present?) if attrs[:custom_fields_data].is_a?(Hash)
    score
  end

  def self.visitor_completeness_score(visitor)
    score = 0
    score += 1 if visitor.full_name.present?
    score += 1 if visitor.email.present?
    score += 1 if visitor.phone.present?
    score += 1 if visitor.gender.present?
    score += 1 if visitor.age.present?
    score += 1 if visitor.role.present?
    score += visitor.custom_fields_data.values.count(&:present?) if visitor.custom_fields_data.is_a?(Hash)
    score
  end

  def self.preferred_label_keys(labels_data)
    keys = (labels_data || {}).keys
    label_keys = keys.select { |k| k.to_s.match?(/^Label \d+$/) }
    if label_keys.any?
      label_keys.sort_by { |k| k.to_s.match(/^Label (\d+)$/)[1].to_i }
    else
      keys
    end
  end

  def self.sanitize_custom_fields(custom_fields, labels_data)
    allowed_keys = preferred_label_keys(labels_data)
    return {} if allowed_keys.empty?
    custom_fields.slice(*allowed_keys).transform_values { |v| v.nil? ? '' : v.to_s }
  end

  def self.merge_label_n_schema(existing_labels, labels_schema)
    merged = (existing_labels || {}).dup
    return merged if labels_schema.blank?

    existing_values = merged.values
    next_index = merged.keys
      .select { |k| k.to_s.match?(/^Label \d+$/) }
      .map { |k| k.to_s.match(/^Label (\d+)$/)[1].to_i }
      .max.to_i

    labels_schema.each_value do |display_name|
      next if existing_values.include?(display_name)
      next_index += 1
      merged["Label #{next_index}"] = display_name
      existing_values << display_name
    end

    merged
  end
end
