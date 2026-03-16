class WishModerationService
  APPROVED_DECISION = 'approved'.freeze
  REJECTED_DECISION = 'rejected'.freeze
  PENDING_DECISION = 'pending'.freeze

  BLOCKED_LANGUAGE_PATTERNS = [
    # English
    /babi/i,
    /bitch/i,
    /bodoh/i,
    /bongok/i,
    /bangang/i,
    /fuck/i,
    /idiot/i,
    /sial/i,
    /stupid/i,
    /celaka/i,
    /sex(?:y)?/i,
    /kill/i,
    /porno?/i,
    /ass(?:hole)?/i,
    /dick/i,
    /pussy/i,
    /cock/i,
    /nude/i,
    /stink/i,
    /shut up/i,
    /go to hell/i,
    /die now/i,
    /piss off/i,
    /screw you/i,
    # Malay / Regional
    /pukimak/i,
    /lancau/i,
    /butuh/i,
    /pantat/i,
    /kimak/i,
    /tetek/i,
    /koteq?/i,
    /jubur/i,
    /haramjadah/i,
    /anjing/i,
    /sundal/i,
    /burit/i,
    /mak kau/i,
    /mak hang/i,
    /buto/i,
    /kanina/i,
    /lanjiao/i,
    /ciao ni ma/i,
    /gan ni na/i,
    /puki/i,
    # Gambling / Spam (Hard Reject)
    /judi\s*online/i,
    /slot(?:\s*online|\s*gacor)?/i,
    /casino/i,
    /gambling/i,
    /poker/i,
    /jackpot/i,
    /maxwin/i,
    /free\s*spin/i,
    /claim\s*bonus/i
  ].freeze

  PROMOTIONAL_PATTERNS = [
    %r{https?://}i,
    /\b(?:www\.|bit\.ly|tinyurl|t\.me|wa\.me|goo\.gl)\b/i,
    /\.(?:com|net|xyz|top|click)\b/i,
    /\b(?:buy now|click here|dm me|fast cash|free money|loan|promo|register now|telegram|whatsapp|invite code|deposit|topup|withdraw)\b/i,
    /\b(?:\+?60|01\d{1}-?\d{7,8})\b/,
    /@\w{4,}/
  ].freeze

  REPETITIVE_PATTERNS = [
    /(.)\1{7,}/,
    /\b(?:ha){6,}\b/i,
    /\b(\w+)(?:\s+\1){3,}\b/i
  ].freeze

  def initialize(message:, guest_name: nil)
    @message = message.to_s
    @guest_name = guest_name
  end

  def call
    return decision_result(REJECTED_DECISION, 'Contains blocked language') if blocked_language?
    return decision_result(PENDING_DECISION, 'Looks like spam or promotion') if promotional?
    return decision_result(PENDING_DECISION, 'Looks repetitive or low quality') if repetitive?

    decision_result(APPROVED_DECISION, 'Allowed by local filter')
  end

  private

  attr_reader :guest_name, :message

  def blocked_language?
    BLOCKED_LANGUAGE_PATTERNS.any? { |pattern| normalized_text.match?(pattern) }
  end

  def promotional?
    PROMOTIONAL_PATTERNS.any? { |pattern| normalized_text.match?(pattern) }
  end

  def repetitive?
    REPETITIVE_PATTERNS.any? { |pattern| normalized_text.match?(pattern) }
  end

  def normalized_text
    @normalized_text ||= [guest_name, message].compact.join(' ').squish
  end

  def decision_result(decision, reason)
    BaseService::ServiceResult.new(
      success: true,
      data: {
        decision: decision,
        reason: reason
      },
      status: :ok
    )
  end
end
