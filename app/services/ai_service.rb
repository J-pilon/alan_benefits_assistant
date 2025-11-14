class AiService
  attr_reader :dispatcher_service, :intent_service, :response_service

  def initialize(dispatcher_service: nil, intent_service: nil, response_service: nil)
    @dispatcher_service = dispatcher_service || FunctionDispatcher
    @intent_service = intent_service || IntentDeterminationService.new
    @response_service = response_service || ResponseGenerationService.new
  end

  def process_query(user_query, profile:, context: nil)
    return error_result("User query cannot be blank") if user_query.blank?
    return error_result("Profile is required") if profile.nil?

    intent_result = determine_intent(user_query)
    return intent_result if intent_result.failure?
    return build_non_actionable_result(intent_result) unless actionable_intent?(intent_result.data)

    execution_result = execute_function(intent_result.data, profile)
    return error_result(execution_result.error) if execution_result.failure?

    response_result = generate_response(user_query, execution_result.data, context)
    return error_result(response_result.error) if response_result.failure?

    success_result(
      function: intent_result.data[:function],
      params: intent_result.data[:params],
      intent_confidence: intent_result.data[:confidence],
      function_result: execution_result.data,
      response: response_result.data[:response],
      response_confidence: response_result.data[:confidence]
    )
  rescue StandardError => e
    Rails.logger.error("AI Service error: #{e.message}")
    error_result("Failed to process query: #{e.message}")
  end

  private

  def success_result(function:, params:, intent_confidence:, function_result:, response:, response_confidence:)
    Result.success(
      function: function,
      params: params,
      intent_confidence: intent_confidence,
      function_result: function_result,
      response: response,
      response_confidence: response_confidence
    )
  end

  def error_result(message)
    Result.failure(message)
  end

  def build_non_actionable_result(intent_result)
    success_result(
      function: intent_result.data[:function],
      params: intent_result.data[:params],
      intent_confidence: intent_result.data[:confidence]
    )
  end

  def actionable_intent?(intent_data)
    intent_data[:function].present? &&
      intent_data[:function] != "unknown" &&
      intent_data[:function] != "error"
  end

  def execute_function(intent_data, profile)
    @dispatcher_service.dispatch(
      intent_data[:function],
      params: intent_data[:params],
      context: { profile: profile }
    )
  end

  def generate_response(user_query, function_result, context)
    @response_service.perform(
      user_query: user_query,
      data: function_result,
      context: context
    )
  end

  def determine_intent(user_query)
    @intent_service.perform(user_query)
  end
end
