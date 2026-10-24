# frozen_string_literal: true

class BusinessMatchingSellerExportService
  def initialize(event)
    @event = event
  end

  def generate_xlsx
    sessions = fetch_sessions
    host_lookup, participant_lookup = fetch_hosts_and_profiles
    exhibitor_kit_lookup, vendor_profile_lookup = fetch_exhibitors

    package = Axlsx::Package.new
    workbook = package.workbook

    styles = build_styles(workbook)

    add_sellers_and_profiles_sheet(workbook, styles, sessions, host_lookup, participant_lookup, exhibitor_kit_lookup, vendor_profile_lookup)
    add_summary_sheet(workbook, styles, sessions, host_lookup)

    package.to_stream.read
  end

  private

  attr_reader :event

  def fetch_sessions
    sessions = event.business_matching_sessions.unarchived
    sessions.sort_by do |s|
      table_num = s.location.to_s.gsub(/\D/, '').to_i
      [table_num.zero? ? 999_999 : table_num, s.location.to_s.downcase, s.id]
    end
  end

  def fetch_hosts_and_profiles
    assignments = BusinessHostAssignment.where(event_id: event.id).includes(:user)
    host_lookup = {}
    host_users = []

    assignments.each do |assignment|
      next unless assignment.business_matching_event_id.present? && assignment.user.present?

      host_lookup[assignment.business_matching_event_id.to_s] = assignment.user
      host_users << assignment.user
    end

    participants = BusinessMatchingParticipant.where(
      event_id: event.id,
      registerable_type: 'User',
      registerable_id: host_users.map(&:id).uniq
    )
    participant_lookup = participants.each_with_object({}) do |p, memo|
      memo[p.registerable_id] = p
    end

    [host_lookup, participant_lookup]
  end

  def fetch_exhibitors
    exhibitors = event.exhibitors.includes(:vendor, :exhibitor_kits)
    vendor_ids = exhibitors.map(&:vendor_id).compact.uniq
    vendor_profiles = VendorProfile.where(vendor_id: vendor_ids).each_with_object({}) do |vp, memo|
      memo[vp.vendor_id] = vp
    end

    exhibitor_by_vendor_id = exhibitors.each_with_object({}) do |ev, memo|
      memo[ev.vendor_id] = ev
    end

    all_kits = exhibitors.flat_map do |ev|
      ev.exhibitor_kits.map { |ek| { exhibitor: ev, kit: ek, vendor_profile: vendor_profiles[ev.vendor_id] } }
    end

    exhibitor_lookup = {
      by_vendor_id: exhibitor_by_vendor_id,
      vendor_profiles: vendor_profiles,
      all_kits: all_kits
    }

    [exhibitor_lookup, vendor_profiles]
  end

  STOP_WORDS = Set.new(%w[sdn bhd sendirian berhad group hotel hotels resort resorts company co ltd trading enterprise services sbc malaysia])
  GENERIC_EMAIL_DOMAINS = Set.new(%w[gmail.com yahoo.com hotmail.com outlook.com icloud.com mail.com live.com ymail.com proton.me protonmail.com])
  IGNORED_FASCIA = Set.new(%w[none tba nonerawspace rawspace none(rawspace)])
  LEGAL_SUFFIXES = /\b(sdn\s*bhd|sendirian\s*berhad|bhd|berhad|co\s*ltd|ltd|inc|llc|plc|enterprise|trading|group|holdings|corporation)\b/i

  def match_exhibitor(session, host_user, exhibitor_data)
    all_kits = exhibitor_data[:all_kits]

    # 1. Match by host vendor account
    if host_user.present?
      vendor_match = all_kits.find { |k| k[:exhibitor].vendor_id == host_user.id }
      return vendor_match if vendor_match

      # 2. Match by exact PIC email
      host_email_norm = normalize(host_user.email)
      if host_email_norm.present?
        email_match = all_kits.find { |k| normalize(k[:kit].pic_email_address) == host_email_norm }
        return email_match if email_match
      end
    end

    # 3. Clean Company / Brand Name matching
    s_clean = clean_company_name(session.title)
    s_norm = normalize(s_clean)

    if s_norm.length >= 3
      all_kits.each do |k|
        kit = k[:kit]
        c_clean = clean_company_name(kit.company_name)
        c_norm = normalize(c_clean)

        f_raw = kit.name_on_fascia.to_s.strip
        f_clean = clean_company_name(f_raw)
        f_norm = normalize(f_clean)
        f_norm = '' if IGNORED_FASCIA.include?(normalize(f_raw))

        # Exact cleaned brand match
        if (c_norm.length >= 3 && s_norm == c_norm) || (f_norm.length >= 3 && s_norm == f_norm)
          return k
        end

        # Substantial prefix match (must be at least 6 alphanumeric characters to avoid collisions)
        if (c_norm.length >= 6 && s_norm.length >= 6 && (c_norm.start_with?(s_norm) || s_norm.start_with?(c_norm))) ||
           (f_norm.length >= 6 && s_norm.length >= 6 && (f_norm.start_with?(s_norm) || s_norm.start_with?(f_norm)))
          return k
        end
      end
    end

    # 4. Corporate email domain match (must also share brand context)
    if host_user.present?
      h_dom = email_domain(host_user.email)
      if h_dom.present?
        domain_root = h_dom.split('.').first.to_s
        domain_match = all_kits.find do |k|
          k_dom = email_domain(k[:kit].pic_email_address)
          next false if k_dom.blank? || h_dom != k_dom

          c_clean = clean_company_name(k[:kit].company_name)
          s_clean.include?(domain_root) || c_clean.include?(domain_root) || (s_clean.split & c_clean.split).any?
        end
        return domain_match if domain_match
      end
    end

    nil
  end

  def clean_company_name(name)
    return '' if name.blank?

    name.to_s.downcase
        .gsub(LEGAL_SUFFIXES, '')
        .gsub(/[^a-z0-9\s]/, ' ')
        .strip
        .squeeze(' ')
  end

  def email_domain(email)
    domain = email.to_s.split('@').last.to_s.downcase.strip
    return nil if GENERIC_EMAIL_DOMAINS.include?(domain)

    domain.presence
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^a-z0-9]/, '')
  end

  def format_schedule(session)
    return '' unless session.start_date.present? && session.end_date.present?

    date_str = if session.start_date == session.end_date
                 session.start_date.strftime('%-d %b %Y')
               else
                 "#{session.start_date.strftime('%-d %b %Y')} – #{session.end_date.strftime('%-d %b %Y')}"
               end

    time_str = "#{session.start_time} – #{session.end_time}"
    "#{date_str}, #{time_str}"
  end

  def build_styles(workbook)
    wb_styles = workbook.styles
    {
      header: wb_styles.add_style(
        bg_color: '1E293B',
        fg_color: 'FFFFFF',
        b: true,
        alignment: { horizontal: :center, vertical: :center, wrap_text: true }
      ),
      summary_header: wb_styles.add_style(
        bg_color: '334155',
        fg_color: 'FFFFFF',
        b: true,
        alignment: { horizontal: :center, vertical: :center }
      ),
      cell: wb_styles.add_style(
        alignment: { vertical: :top, wrap_text: true }
      ),
      cell_center: wb_styles.add_style(
        alignment: { horizontal: :center, vertical: :top }
      )
    }
  end

  def add_sellers_and_profiles_sheet(workbook, styles, sessions, host_lookup, participant_lookup, exhibitor_data, _vendor_profiles)
    include_exhibitors = exhibitor_data[:all_kits].any?

    headers = [
      'Table',
      'Seller Name',
      'Session Schedule',
      'Host Name',
      'Host Email',
      'Host Phone',
      'BM Profile Description',
      'Capabilities & Offerings',
      'Sourcing Intent (Seeking)',
      'Offering Tags',
      'Interest Tags'
    ]

    if include_exhibitors
      headers += [
        'Exhibitor PIC Name',
        'Exhibitor PIC Email',
        'Exhibitor PIC Phone',
        'PIC Designation',
        'Company Address',
        'Country',
        'Industry / Category',
        'Company Profile & Notes'
      ]
    end

    workbook.add_worksheet(name: 'Sellers & Profiles') do |sheet|
      sheet.add_row headers, style: styles[:header], height: 28

      sessions.each do |session|
        host_user = host_lookup[session.id.to_s]
        h_profile = host_user ? participant_lookup[host_user.id] : nil
        exhibitor_match = include_exhibitors ? match_exhibitor(session, host_user, exhibitor_data) : nil
        kit = exhibitor_match&.[](:kit)
        vp = exhibitor_match&.[](:vendor_profile)

        profile_data = h_profile&.profile_data || {}
        offering_tags = h_profile&.offering_tags&.join(', ')
        interest_tags = h_profile&.interest_tags&.join(', ')

        row = [
          session.location.presence || "Table #{session.id}",
          session.title,
          format_schedule(session),
          host_user&.full_name,
          host_user&.email,
          host_user&.phone,
          profile_data['description'],
          profile_data['capabilities'],
          profile_data['sourcing_intent'],
          offering_tags,
          interest_tags
        ]

        if include_exhibitors
          pic_name = kit&.pic_full_name.presence || vp&.person_in_charge
          pic_email = kit&.pic_email_address.presence
          pic_phone = kit&.pic_contact_number.presence
          pic_position = kit&.pic_position.presence
          company_address = kit&.company_address.presence || vp&.address
          country = kit&.country.presence
          category = vp&.category.presence
          company_notes = vp&.description.presence || vp&.company_profile.presence || kit&.special_requirements

          row += [
            pic_name,
            pic_email,
            pic_phone,
            pic_position,
            company_address,
            country,
            category,
            company_notes
          ]
        end

        sheet.add_row row, style: styles[:cell]
      end

      widths = [12, 30, 26, 22, 26, 16, 35, 35, 35, 24, 24]
      widths += [22, 26, 16, 18, 35, 14, 18, 30] if include_exhibitors
      sheet.column_widths(*widths)
    end
  end

  def add_summary_sheet(workbook, styles, sessions, host_lookup)
    headers = ['Table', 'Seller Name', 'Session Schedule', 'Host', 'Email']

    workbook.add_worksheet(name: 'seller_list') do |sheet|
      sheet.add_row headers, style: styles[:summary_header], height: 26

      sessions.each do |session|
        host_user = host_lookup[session.id.to_s]
        row = [
          session.location.presence || "Table #{session.id}",
          session.title,
          format_schedule(session),
          host_user&.full_name,
          host_user&.email
        ]
        sheet.add_row row, style: styles[:cell]
      end

      sheet.column_widths 14, 32, 28, 24, 28
    end
  end
end
