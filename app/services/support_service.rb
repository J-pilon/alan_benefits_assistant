class SupportService
  attr_reader :profile, :ai_service

  def initialize(profile:, ai_service: nil)
    @profile = profile
    @ai_service = ai_service || AiService.new
  end

  def process_user_query(user_message)
    if ai_chat_enabled?
      process_with_ai(user_message)
    else
      create_support_ticket(user_message)
    end
  rescue StandardError => e
    Rails.logger.error("SupportService error: #{e.message}\n#{e.backtrace.join("\n")}")
    # Fallback to support ticket if AI fails
    create_support_ticket(user_message, error: e.message)
  end

  private

  def process_with_ai(user_message)
    ai_result = ai_service.process_query(user_message, profile: profile)
    return ai_result if ai_result.failure?

    chat_message = save_chat_message(user_message, ai_result.data)

    success_response(
      chat_message: chat_message,
      source: :ai
    )
  end

  def create_support_ticket(user_message, error: nil)
    chat_message = profile.chat_messages.create!(
      user_message: user_message,
      ai_response: support_ticket_response,
      ai_metadata: {
        source: "support_ticket",
        feature_flag_disabled: !ai_chat_enabled?,
        error: error
      }.compact
    )

    support_ticket = profile.support_tickets.create!(
      user_question: user_message,
      chat_message: chat_message,
      status: "pending",
      priority: determine_priority(user_message),
      initial_context: {
        error: error,
        ai_disabled: !ai_chat_enabled?,
        created_via: "chat_interface"
      }.compact.to_json
    )

    success_response(
      chat_message: chat_message,
      source: :support_ticket,
      ticket: support_ticket
    )
  end

  def save_chat_message(user_message, ai_result)
    profile.chat_messages.create!(
      user_message: user_message,
      ai_response: ai_result[:response] || ai_result[:error] || "I'm sorry, I couldn't process that request.",
      ai_metadata: {
        function: ai_result[:function],
        params: ai_result[:params],
        intent_confidence: ai_result[:intent_confidence],
        response_confidence: ai_result[:response_confidence],
        error: ai_result[:error],
        source: "ai"
      }.compact
    )
  end

  def support_ticket_response
    <<~MESSAGE.strip
      Thanks for your question! Our AI assistant is temporarily unavailable, but I've created a support ticket for you.

      A member of our team will review your question and get back to you within 24 hours.

      You can continue using the chat - all your messages will be saved.
    MESSAGE
  end

  def determine_priority(user_message)
    urgent_keywords = [ "urgent", "emergency", "immediately", "asap", "critical", "now" ]
    high_keywords = [ "important", "soon", "quickly", "need help", "problem" ]

    message_downcase = user_message.downcase

    return "urgent" if urgent_keywords.any? { |word| message_downcase.include?(word) }
    return "high" if high_keywords.any? { |word| message_downcase.include?(word) }

    "normal"
  end

  def success_response(chat_message:, source:, ticket: nil)
    {
      success: true,
      chat_message: {
        id: chat_message.id,
        user_message: chat_message.user_message,
        ai_response: chat_message.ai_response,
        created_at: chat_message.created_at.iso8601
      },
      source: source,
      support_ticket: ticket ? {
        id: ticket.id,
        status: ticket.status,
        priority: ticket.priority
      } : nil
    }.compact
  end

  def ai_chat_enabled?
    FeatureFlags.ai_chat_enabled?
  end
end
