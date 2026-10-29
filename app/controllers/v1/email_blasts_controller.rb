module V1
  # Org-owner-only mass email to an event's delegates. A blast is saved as a
  # draft, previewed and test-sent, then sent exactly once.
  class EmailBlastsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_blast, only: %i[show update destroy preview test deliver duplicate]

    # GET /v1/events/:event_id/email_blasts
    def index
      authorize EmailBlast, :index?
      blasts = @event.email_blasts.order(created_at: :desc).with_attached_banner
      blasts = blasts.where(status: params[:status]) if EmailBlast::STATUSES.include?(params[:status])
      render json: { data: blasts.map { |b| serialize(b) } }
    end

    # GET /v1/events/:event_id/email_blasts/audience?ticket_type_ids[]=
    def audience
      authorize EmailBlast, :index?
      blast = @event.email_blasts.new(audience: audience_params)
      setting = @event.event_email_setting
      render json: {
        recipient_count: blast.recipient_tickets.to_a.size,
        sender_name: setting&.sender_name.presence || @event.title,
        sender_address: setting&.sender_address.presence || ApplicationMailer::DEFAULT_SENDER_ADDRESS
      }
    end

    def show
      authorize @blast
      render json: { data: serialize(@blast, with_recipients: true) }
    end

    def create
      authorize EmailBlast
      blast = @event.email_blasts.new(blast_params.merge(created_by: current_user))
      new_files.each { |file| blast.attachments.attach(file) }
      blast.save ? render(json: { data: serialize(blast) }, status: :created) : render_invalid(blast)
    end

    def update
      authorize @blast
      return render_locked unless @blast.editable?

      @blast.attachments.where(id: Array(params[:remove_attachment_ids])).find_each(&:purge)
      @blast.assign_attributes(blast_params)
      new_files.each { |file| @blast.attachments.attach(file) }
      @blast.save ? render(json: { data: serialize(@blast.reload) }) : render_invalid(@blast)
    end

    def destroy
      authorize @blast
      return render_locked unless @blast.editable?

      @blast.destroy!
      head :no_content
    end

    # POST .../:id/duplicate - a new draft from any blast, or a named template
    # when template_name is given.
    def duplicate
      authorize @blast, :create?
      copy = @blast.duplicate(created_by: current_user, template_name: params[:template_name])
      copy.save ? render(json: { data: serialize(copy) }, status: :created) : render_invalid(copy)
    end

    # GET .../:id/preview - the exact HTML recipients get, banner inlined.
    def preview
      authorize @blast
      render json: { html: rendered_html(EmailBlastMailer.blast_email(@blast, current_user.email).message), subject: @blast.subject }
    end

    # POST /v1/events/:event_id/email_blasts/preview_draft - renders unsaved edits for the
    # live preview. Uses the saved draft's banner when draft_id is given; saves nothing.
    def preview_draft
      authorize EmailBlast, :preview?
      blast = params[:draft_id].present? ? @event.email_blasts.find(params[:draft_id]) : @event.email_blasts.new
      blast.assign_attributes(preview_params)
      blast.subject = '(no subject)' if blast.subject.blank?
      blast.body = blast.sanitized_body
      render json: { html: rendered_html(EmailBlastMailer.blast_email(blast, current_user.email, preview: true).message) }
    end

    # POST .../:id/test - one copy to the signed-in owner, not logged as a send.
    def test
      authorize @blast
      EmailBlastMailer.blast_email(@blast, current_user.email).deliver_later
      render json: { message: "Test sent to #{current_user.email}" }
    end

    # POST .../:id/deliver
    def deliver
      authorize @blast
      count = @blast.recipient_tickets.to_a.size
      return render json: { errors: ['No recipients match this audience'] }, status: :unprocessable_content if count.zero?

      # Atomic claim so a double click can't send twice.
      claimed = EmailBlast.where(id: @blast.id, status: 'draft')
                          .update_all(status: 'sending', recipient_count: count, sent_at: Time.current)
      return render_locked if claimed.zero?

      SendEmailBlastJob.perform_later(@blast.id)
      render json: { data: serialize(@blast.reload) }, status: :accepted
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_blast
      @blast = @event.email_blasts.find(params[:id])
    end

    def audience_params
      {
        'ticket_type_ids' => Array(params[:ticket_type_ids]).map(&:to_i).select(&:positive?),
        'include_pending' => ActiveModel::Type::Boolean.new.cast(params[:include_pending]) == true
      }
    end

    def blast_params
      permitted = params.permit(:subject, :body, :banner, :body_format, :style_key).to_h
      permitted[:audience] = audience_params if params.key?(:ticket_type_ids) || params.key?(:include_pending)
      permitted
    end

    def preview_params
      params.permit(:subject, :body, :body_format, :style_key).to_h
    end

    # The HTML recipients get, with inline images (cid:) swapped for data URIs so a browser can show it.
    def rendered_html(message)
      html = message.html_part&.body&.decoded || message.body.decoded
      message.attachments.select(&:inline?).each do |att|
        html = html.gsub("cid:#{att.cid}", "data:#{att.mime_type};base64,#{Base64.strict_encode64(att.body.decoded)}")
      end
      html
    end

    def new_files
      Array(params[:attachments]).select { |f| f.respond_to?(:original_filename) }
    end

    def render_invalid(blast)
      render json: { errors: blast.errors.full_messages }, status: :unprocessable_content
    end

    def render_locked
      render json: { errors: ['This email has already been sent'] }, status: :unprocessable_content
    end

    def serialize(blast, with_recipients: false)
      {
        id: blast.id,
        name: blast.name,
        subject: blast.subject,
        body: blast.body,
        status: blast.status,
        ticket_type_ids: blast.ticket_type_ids,
        include_pending: blast.include_pending?,
        body_format: blast.body_format,
        style_key: blast.style_key,
        attachments: blast.attachments.map { |a| { id: a.id, filename: a.filename.to_s, byte_size: a.byte_size } },
        banner_url: blast.banner.attached? ? url_for(blast.banner) : nil,
        recipient_count: blast.recipient_count,
        delivery_counts: blast.editable? ? {} : blast.delivery_counts,
        sent_at: blast.sent_at,
        created_at: blast.created_at,
        sender_name: blast.created_by&.full_name
      }.tap { |json| json[:recipients] = recipients_json(blast) if with_recipients }
    end

    # Per-recipient outcome for the history detail (capped; the Email Status page has the full list).
    def recipients_json(blast)
      blast.deliveries.order(:recipient).limit(500).map do |d|
        { email: d.recipient, status: d.status, failure_reason: d.failure_reason, sent_at: d.sent_at }
      end
    end
  end
end
