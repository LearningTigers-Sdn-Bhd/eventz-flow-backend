# View helpers shared by every mailer template. A template calls `email_page`
# once at the top to pick its colour, icon and heading; the `email` layout and
# the `emails/_*` partials read what it stores.
module EmailHelper
  # accent = buttons, links, badge circle; dark = badge text and dark-mode fill.
  THEMES = {
    green: { accent: '#15803d', dark: '#14532d' },
    amber: { accent: '#b45309', dark: '#78350f' },
    orange: { accent: '#c2410c', dark: '#7c2d12' },
    blue: { accent: '#1d6fb8', dark: '#123f6b' },
    purple: { accent: '#6d28d9', dark: '#3b1a78' },
    teal: { accent: '#0f766e', dark: '#134e4a' },
    slate: { accent: '#334155', dark: '#0f172a' },
    red: { accent: '#b91c1c', dark: '#7f1d1d' },
    violet: { accent: '#5b3fd0', dark: '#33237a' },
    sky: { accent: '#0369a1', dark: '#0c4a6e' }
  }.freeze

  # PNG files in the panel's public/email-icons folder.
  ICONS = %w[
    alert arrow-up award bell cal-check cal-x calendar card check clock file gift heart hourglass
    info key link list lock mail message refresh shield store ticket users x
  ].freeze

  AUTOMATED_FOOTER = 'This is an automated email from EventzFlow. Please do not reply to this email.'.freeze

  # Sets the colour, icon, badge label, heading and footer for the current email.
  def email_page(type, icon:, label:, title:, tagline: nil, footer: AUTOMATED_FOOTER)
    theme = THEMES.fetch(type)
    raise ArgumentError, "unknown email icon #{icon}" unless ICONS.include?(icon.to_s)

    @email = theme.merge(
      tint: email_mix(theme[:accent], 0.12),
      tint_border: email_mix(theme[:accent], 0.30),
      icon: icon.to_s,
      label: label,
      title: title,
      tagline: tagline,
      footer: footer
    )
    nil
  end

  def email_icon_url(name)
    base = ENV.fetch('FRONTEND_URL', ENV.fetch('APP_FRONTEND_URL', 'http://localhost:3001')).to_s.chomp('/')
    "#{base}/email-icons/#{name}.png"
  end

  # Blend a hex colour with white; ratio is the share of the colour kept.
  def email_mix(hex, ratio)
    channels = [1, 3, 5].map { |i| ((hex[i, 2].to_i(16) * ratio) + (255 * (1 - ratio))).round }
    format('#%02x%02x%02x', *channels)
  end

  # Drops blank rows so optional fields (venue, order id…) vanish cleanly.
  def email_rows(rows)
    rows.reject { |_, value| value.blank? }
  end

  def email_date_range(event)
    start_date = event.start_date.strftime('%B %d, %Y')
    return start_date unless event.end_date.present? && event.end_date.to_date != event.start_date.to_date

    "#{start_date} – #{event.end_date.strftime('%B %d, %Y')}"
  end

  def email_money(currency, amount)
    "#{currency.presence || 'MYR'} #{format('%.2f', amount.to_f)}"
  end
end
