class ResponseGenerationService
  attr_reader :ai_client, :redaction_service

  def initialize(ai_client: nil, redaction_service: nil)
    @ai_client = ai_client || AiClients::OpenaiClient
    @redaction_service = redaction_service || PiiRedaction
  end

  def perform(user_query:, data:, context: nil)
    return error_result("User query cannot be blank") if user_query.blank?
    return error_result("Data cannot be blank") if data.blank?

    sanitized_query = redact_sensitive_information(user_query)
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(sanitized_query, data, context)

    response = ai_client.generate_response(system_prompt: system_prompt, user_prompt: user_prompt)

    success_result(response)
  rescue StandardError => e
    Rails.logger.error("Response Generation error: #{e.message}")
    error_result("Failed to generate response: #{e.message}")
  end

  private

  def redact_sensitive_information(user_data)
    @redaction_service.redact(user_data)
  end

  def build_system_prompt
    <<~PROMPT
      You are a helpful benefits assistant. Generate a clear, concise, and friendly response
      based on the provided data. Your response should:
      - Be written in plain English
      - Be accurate and based only on the provided data
      - Include specific amounts, dates, and limits when available
      - Be professional but conversational
      - Not make up any information not in the provided data

      Format your response as a natural, helpful message to the user.
    PROMPT
  end

  def build_user_prompt(user_query, data, context)
    prompt_parts = []
    prompt_parts << "User Query: #{user_query}"
    prompt_parts << "Data: #{format_data(data)}"
    prompt_parts << "Context: #{context}" if context.present?
    prompt_parts.join("\n\n")
  end

  def format_data(data)
    case data
    when Hash
      data.to_json
    when String
      data
    else
      data.to_s
    end
  end

  def success_result(response)
    {
      "response" => response,
      "confidence" => extract_confidence(response)
    }
  end

  def error_result(message)
    {
      "response" => "I'm sorry, I encountered an error while processing your request.",
      "confidence" => 0.0,
      "error" => message
    }
  end

  def extract_confidence(response)
    # Default confidence score - could be enhanced to extract from AI response
    response.present? ? 0.85 : 0.0
  end
end
