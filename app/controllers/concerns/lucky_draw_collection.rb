module LuckyDrawCollection
  extend ActiveSupport::Concern

  private

  def collection_details(record)
    {
      claimed_at: record.claimed_at&.iso8601,
      gift_taken: record.gift_taken,
      collection_updated_at: record.collection_updated_at&.iso8601
    }
  end

  def save_collection(record)
    authorize record, :update?
    if (params.key?(:claimed) && ![true, false, 'true', 'false'].include?(params[:claimed])) ||
       (params.key?(:gift_taken) && (!params[:gift_taken].is_a?(String) || params[:gift_taken].length > 500)) ||
       (!params.key?(:claimed) && !params.key?(:gift_taken))
      return error_response(message: 'Provide a boolean claimed value or gift_taken text (up to 500 characters)', status: :unprocessable_content)
    end

    skipped = false
    record.with_lock do
      # Local records have no timestamps: never replace a shared edit, even an undo.
      skipped = [true, 'true'].include?(params[:import_only]) && record.collection_updated_at.present?
      unless skipped
        record.claimed_at = [true, 'true'].include?(params[:claimed]) ? (record.claimed_at || Time.current) : nil if params.key?(:claimed)
        record.gift_taken = params[:gift_taken].strip.presence if params.key?(:gift_taken)
        record.collection_updated_at = Time.current
        record.save!
      end
    end
    success_response(data: collection_details(record).merge(skipped: skipped), message: 'Success')
  end
end
