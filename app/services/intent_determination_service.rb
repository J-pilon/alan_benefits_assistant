class IntentDeterminationService
  attr_reader :ai_client, :redaction_service, :dispatcher_service

  def initialize(ai_client: nil, redaction_service: nil, dispatcher_service: nil)
    @ai_client = ai_client || AiClients::OpenaiClient
    @redaction_service = redaction_service || PiiRedaction
    @dispatcher_service = dispatcher_service || FunctionDispatcher
  end

  def perform(user_query)
    return error_result("User query cannot be blank") if user_query.blank?

    redaction_result = redact_sensitive_information(user_query)
    return redaction_result if redaction_result.failure?

    system_prompt = build_system_prompt

    ai_client.determine_intent(system_prompt: system_prompt, user_prompt: redaction_result.data)
  rescue StandardError => e
    Rails.logger.error("Intent Determination error: #{e.message}")
    error_result("Failed to determine intent: #{e.message}")
  end

  private

  def redact_sensitive_information(user_data)
    @redaction_service.redact(user_data)
  end

  def build_system_prompt
    categories_text = categories.any? ? "Categories can be: #{categories.join(', ')}." : ""

    <<~PROMPT
      You are a benefits assistant that helps users understand their health benefits coverage.
      Analyze the user's query and determine which function to call. Return a JSON object with:
      - "function": the function name to call, one of #{function_names.to_json} or "unknown"
      - "params": a hash with relevant parameters (e.g., "category": "massage", "vision", or "dental")
      - "confidence": a float between 0 and 1 indicating confidence in the function selection

      Available functions:
      #{function_list}

      #{categories_text}
      Return ONLY valid JSON, no additional text.
    PROMPT
  end

  def function_names
    registry.all.map { |func| func.name.to_s }
  end

  def function_list
    registry.all.map { |func| "- #{func.name}: #{func.description}" }.join("\n")
  end

  def categories
    registry.all.each do |func|
      enum = func.param_schema.dig("properties", "category", "enum")
      return enum if enum.present?
    end
    []
  end

  def registry
    @dispatcher_service.service.registry
  end

  def function_definitions_file_path
    file_path = Rails.root.join("config", "dispatch_functions.yml")

    raise "Function definition yaml file doesn't exist." unless File.exist?(file_path)

    file_path
  end

  def error_result(message)
    Result.failure(message)
  end
end
