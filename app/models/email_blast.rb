# One organizer-written email to an event's registered delegates. Per-recipient
# outcomes live in EmailDelivery rows (related: this blast), so the Email Status
# page and bounce handling work as for every other mail.
class EmailBlast < ApplicationRecord
  STATUSES = %w[draft sending template].freeze
  FORMATS = %w[rich html].freeze
  # Header look of the EventzFlow layout. 'general' shows the event name in the badge;
  # the others show their own label with the event name underneath.
  STYLES = {
    'general' => { label: 'General', theme: :slate, icon: 'info' },
    'announcement' => { label: 'Announcement', theme: :blue, icon: 'message' },
    'important' => { label: 'Important update', theme: :orange, icon: 'alert' },
    'reminder' => { label: 'Reminder', theme: :teal, icon: 'bell' },
    'invitation' => { label: 'Invitation', theme: :violet, icon: 'calendar' },
    'offer' => { label: 'Special offer', theme: :amber, icon: 'gift' },
    'thanks' => { label: 'Thank you', theme: :green, icon: 'heart' }
  }.freeze
  # Only formatting the editor offers; scripts, images and unsafe styles are
  # stripped (the banner is attached separately).
  ALLOWED_TAGS = %w[p br strong b em i u s a ul ol li h1 h2 h3 blockquote].freeze
  ALLOWED_ATTRIBUTES = %w[href style].freeze

  # Email-safe files only, kept small: SES caps a whole message at 10 MB and
  # base64 adds a third, so 5 MB of files is the practical ceiling.
  MAX_ATTACHMENTS = 5
  MAX_ATTACHMENTS_BYTES = 5.megabytes
  ATTACHMENT_TYPES = %w[
    application/pdf image/jpeg image/png image/gif text/csv
    application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint application/vnd.openxmlformats-officedocument.presentationml.presentation
  ].freeze

  belongs_to :event
  belongs_to :created_by, class_name: 'User', optional: true
  has_one_attached :banner, dependent: :purge_later
  has_many_attached :attachments, dependent: :purge_later
  has_many :deliveries, as: :related, class_name: 'EmailDelivery', dependent: :nullify

  validates :subject, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true, length: { maximum: 100 }, if: :template?
  validates :body_format, inclusion: { in: FORMATS }
  validates :style_key, inclusion: { in: STYLES.keys }
  validate :banner_is_small_image
  validate :attachments_are_allowed

  before_save { self.body = sanitized_body }

  def html? = body_format == 'html'
  def style = STYLES.fetch(style_key, STYLES['general'])
  def draft? = status == 'draft'
  def template? = status == 'template'
  # Drafts and templates can still be edited or deleted; a sent blast is history.
  def editable? = draft? || template?

  def ticket_type_ids
    Array(audience['ticket_type_ids']).map(&:to_i)
  end

  # One ticket per address (first wins), registered and not waitlisted. Mirrors
  # the rule the thank-you mail uses so group buyers get a single copy.
  def recipient_tickets
    scope = event.tickets.where(status: %i[purchased scanned], waiting_list: false)
                 .where.not(attendee_email: [nil, ''])
    scope = scope.where(ticket_type_id: ticket_type_ids) if ticket_type_ids.any?
    scope.select('DISTINCT ON (LOWER(tickets.attendee_email)) tickets.*')
         .order(Arel.sql('LOWER(tickets.attendee_email), tickets.id'))
  end

  # A fresh copy with the same content (banner included), as a draft or a named template.
  def duplicate(created_by:, template_name: nil)
    copy = event.email_blasts.new(
      subject: subject, body: body, body_format: body_format, style_key: style_key, audience: audience, created_by: created_by,
      status: template_name.present? ? 'template' : 'draft', name: template_name.presence
    )
    copy.banner.attach(banner.blob) if banner.attached?
    attachments.each { |file| copy.attachments.attach(file.blob) }
    copy
  end

  def delivery_counts
    deliveries.group(:status).count
  end

  # What actually gets stored and sent (also used to preview unsaved edits).
  def sanitized_body
    if html?
      Loofah.html5_document(body.to_s).scrub!(:prune).to_s
    else
      Rails::HTML5::SafeListSanitizer.new.sanitize(body.to_s, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
    end
  end

  private

  # Rich: the editor's small tag set. Html: a full email, so tables, images and
  # inline styles stay, but scripts, <style> blocks, event handlers and
  # javascript: links are removed (use inline styles).
  def attachments_are_allowed
    return unless attachments.attached?

    files = attachments.map(&:blob)
    errors.add(:attachments, "are limited to #{MAX_ATTACHMENTS} files") if files.size > MAX_ATTACHMENTS
    errors.add(:attachments, 'must be a PDF, Office document, CSV or image') unless files.all? { |f| f.content_type.in?(ATTACHMENT_TYPES) }
    errors.add(:attachments, "must total under #{MAX_ATTACHMENTS_BYTES / 1.megabyte} MB") if files.sum(&:byte_size) > MAX_ATTACHMENTS_BYTES
  end

  def banner_is_small_image
    return unless banner.attached?

    errors.add(:banner, 'must be a JPG, PNG or GIF') unless banner.content_type.in?(%w[image/jpeg image/png image/gif])
    errors.add(:banner, 'must be under 3 MB') if banner.blob.byte_size > 3.megabytes
  end
end
