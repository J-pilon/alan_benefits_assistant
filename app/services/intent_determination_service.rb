class IntentDeterminationService
  attr_reader :ai_client, :redaction_service

  def initialize(ai_client: nil, redaction_service: nil)
    @ai_client = ai_client || AiClients::OpenaiClient
    @redaction_service = redaction_service || PiiRedaction
  end

  def perform(user_query)
    return error_result("User query cannot be blank") if user_query.blank?

    sanitized_query = redact_sensitive_information(user_query)
    system_prompt = build_system_prompt

    ai_client.determine_intent(system_prompt: system_prompt, user_prompt: sanitized_query)
  rescue StandardError => e
    Rails.logger.error("Intent Determination error: #{e.message}")
    error_result("Failed to determine intent: #{e.message}")
  end

  private

  def redact_sensitive_information(user_data)
    @redaction_service.redact(user_data)
  end

  def build_system_prompt
    functions = sanitized_function_definitions
    function_names = functions.map { |f| f[:name] }.compact
    function_list = functions.map { |f| "- #{f[:name]}: #{f[:description]}" }.join("\n")

    # Extract categories from the first function that has category enum
    categories = []
    functions.each do |func|
      category_enum = func.dig(:params_schema, "properties", "category", "enum")
      if category_enum.present?
        categories = category_enum
        break
      end
    end

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

  def function_definitions
    yaml_content = YAML.load_file(function_definitions_file_path)

    yaml_content["functions"] || []
  end

  def sanitized_function_definitions
    function_definitions.map do |func_def|
      {
        name: func_def["name"],
        description: func_def["description"],
        params_schema: func_def["parameters"]
      }
    end
  end

  def function_definitions_file_path
    file_path = Rails.root.join("config", "dispatch_functions.yml")

    raise "Function definition yaml file doesn't exist." unless File.exist?(file_path)

    file_path
  end

  def error_result(message)
    {
      "function" => "error",
      "params" => {},
      "confidence" => 0.0,
      "error" => message
    }
  end
end
