class EventSeatSession < ApplicationRecord
  belongs_to :event
  has_many :event_seat_venues, dependent: :destroy
  accepts_nested_attributes_for :event_seat_venues, allow_destroy: true

  before_validation :set_public_id, on: :create
  before_validation :generate_slug, on: :create

  enum :status, { draft: 0, published: 1, cancelled: 2 }

  validates :name, presence: true
  validates :public_id, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :start_datetime, presence: true
  validates :end_datetime, presence: true
  validate :end_date_after_start_date

  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }

  def archive
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  def deep_duplicate!(name_suffix: " copy")
    new_session = nil

    ActiveRecord::Base.transaction do
      new_session = dup
      new_session.name = "#{name}#{name_suffix}"
      new_session.created_at = nil
      new_session.updated_at = nil
      new_session.deleted_at = nil
      new_session.save!

      event_seat_venues.each do |venue|
        new_venue = new_session.event_seat_venues.create!(
          name: venue.name,
          total_row: venue.total_row,
          total_column: venue.total_column,
          aspect_ratio: venue.aspect_ratio
        )

        if venue.image.attached?
          new_venue.image.attach(venue.image.blob)
        end

        venue.event_seat_sections.each do |section|
          new_section = new_venue.event_seat_sections.create!(
            name: section.name,
            price: section.price,
            start_row: section.start_row,
            start_column: section.start_column,
            seat_row: section.seat_row,
            seat_column: section.seat_column,
            row_span: section.row_span,
            col_span: section.col_span
          )

          section.event_ticket_seats.each do |seat|
            new_section.event_ticket_seats.create!(
              name: seat.name,
              extra_price: seat.extra_price,
              row_set: seat.row_set,
              col_set: seat.col_set,
              ticket_id: nil,
              visitor_id: nil
            )
          end
        end
      end
    end

    new_session
  end

  private

  def set_public_id
    self.public_id ||= SecureRandom.uuid
  end

  def generate_slug
    return if slug.present?

    base_slug = name.to_s.parameterize
    candidate = base_slug
    counter = 0

    while EventSeatSession.with_deleted.exists?(slug: candidate)
      counter += 1
      candidate = "#{base_slug}-#{counter}"
    end

    self.slug = candidate
  end

  def end_date_after_start_date
    return if end_datetime.blank? || start_datetime.blank?

    if end_datetime < start_datetime
      errors.add(:end_datetime, "must be after the start date")
    end
  end
end
