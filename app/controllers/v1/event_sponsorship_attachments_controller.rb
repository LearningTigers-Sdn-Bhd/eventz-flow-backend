module V1
  class EventSponsorshipAttachmentsController < ApplicationController
    before_action :set_sponsorship
    before_action :set_attachment, only: [:destroy]
    before_action :authorize_attachment, only: [:destroy]

    # GET /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_attachments
    def index
      authorize EventSponsorshipAttachment
      @attachments = policy_scope(EventSponsorshipAttachment).where(event_sponsorship: @sponsorship)
      
      render json: @attachments.map { |a| a.as_json.merge(file_url: a.file.attached? ? url_for(a.file) : nil) }
    end

    # POST /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_attachments
    def create
      @attachment = @sponsorship.event_sponsorship_attachments.new(attachment_params)
      @attachment.uploaded_by = current_user
      authorize @attachment

      if @attachment.save
        render json: @attachment.as_json.merge(file_url: url_for(@attachment.file)), status: :created
      else
        render json: @attachment.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_attachments/:id
    def destroy
      @attachment.soft_delete
      head :no_content
    end

    private

    def set_sponsorship
      @sponsorship = EventSponsorship.find(params[:event_sponsorship_id])
    end

    def set_attachment
      @attachment = @sponsorship.event_sponsorship_attachments.find(params[:id])
    end

    def authorize_attachment
      authorize @attachment
    end

    def attachment_params
      params.require(:event_sponsorship_attachment).permit(
        :event_sponsorship_payment_id,
        :attachment_type,
        :file
      )
    end
  end
end
