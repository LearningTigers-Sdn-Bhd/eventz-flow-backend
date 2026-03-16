module V1
  class ClonedVoicesController < ApplicationController
    before_action :set_cloned_voice, only: %i[show update destroy attach]
    before_action :authorize_cloned_voice, only: %i[show update destroy attach]

    # GET /v1/cloned_voices
    # GET /v1/users/:user_id/cloned_voices
    # GET /v1/events/:event_id/cloned_voices
    def index
      @cloned_voices = policy_scope(ClonedVoice)
      
      if params[:user_id]
        @cloned_voices = @cloned_voices.where(owner_id: params[:user_id])
      end

      if params[:event_id]
        @cloned_voices = @cloned_voices.where(event_id: params[:event_id])
      end

      render json: @cloned_voices
    end

    # GET /v1/cloned_voices/:id
    def show
      render json: @cloned_voice
    end

    # POST /v1/cloned_voices
    def create
      @cloned_voice = ClonedVoice.new(cloned_voice_params)
      @cloned_voice.creator = current_user
      
      # Owner is either the provided owner_id (if current_user is superadmin)
      # or simply the current_user (for most organizers)
      @cloned_voice.owner = if current_user.org_owner? && params[:cloned_voice][:owner_id].present?
                              User.find(params[:cloned_voice][:owner_id])
                            else
                              current_user
                            end
      
      @cloned_voice.status = :pending

      authorize @cloned_voice

      if @cloned_voice.save
        CloneVoiceJob.perform_later(@cloned_voice.id)
        render json: @cloned_voice, status: :created
      else
        render json: { errors: @cloned_voice.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/cloned_voices/:id
    def update
      if @cloned_voice.update(cloned_voice_params)
        render json: @cloned_voice
      else
        render json: { errors: @cloned_voice.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /v1/cloned_voices/:id
    def destroy
      @cloned_voice.destroy
      head :no_content
    end

    # POST /v1/cloned_voices/:id/attach
    # Body: { event_id: 123 }
    def attach
      event = Event.find(params[:event_id])
      # Authorization is handled by policy (only Org Owner or maybe Event Admin)
      
      if @cloned_voice.update(event: event)
        render json: @cloned_voice
      else
        render json: { errors: @cloned_voice.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def set_cloned_voice
      @cloned_voice = ClonedVoice.find(params[:id])
    end

    def authorize_cloned_voice
      authorize @cloned_voice
    end

    def cloned_voice_params
      params.require(:cloned_voice).permit(:owner_id, :event_id, :name, audio_samples: [], settings: {})
    end
  end
end
