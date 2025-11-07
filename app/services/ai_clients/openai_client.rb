require "openai"

module AiClients
  class OpenaiClient < AiClient
    class << self
      def determine_intent(system_prompt:, user_prompt:)
        return error_response("System prompt cannot be blank") if system_prompt.blank?
        return error_response("User prompt cannot be blank") if user_prompt.blank?

        client = openai_client
        return error_response("OpenAI API key not configured") unless client

        deterministic_temp = 0.3
        model_name = "gpt-4o-mini"
        response_format = "json_object"

        begin
          response = client.chat(
            parameters: {
              model: model_name,
              messages: [
                { role: "system", content: system_prompt },
                { role: "user", content: user_prompt }
              ],
              temperature: deterministic_temp,
              response_format: { type: response_format }
            }
          )

          parse_intent_response(response)
        rescue StandardError => e
          Rails.logger.error("OpenAI API error in determine_intent: #{e.message}")
          error_response("Failed to determine intent: #{e.message}")
        end
      end

      def generate_response(system_prompt:, user_prompt:)
        return "I'm sorry, I don't have enough information to generate a response." if system_prompt.blank? || user_prompt.blank?

        client = openai_client
        return "I'm sorry, the service is temporarily unavailable." unless client

        varied_temp = 0.7
        model_name = "gpt-4o-mini"

        begin
          response = client.chat(
            parameters: {
              model: model_name,
              messages: [
                { role: "system", content: system_prompt },
                { role: "user", content: user_prompt }
              ],
              temperature: varied_temp
            }
          )

          response.dig("choices", 0, "message", "content") || "I'm sorry, I couldn't generate a response."
        rescue StandardError => e
          Rails.logger.error("OpenAI API error in generate_response: #{e.message}")
          "I'm sorry, I encountered an error while generating a response."
        end
      end

      private

      def openai_client
        api_key = Rails.application.credentials.dig(:openai, :api_key)
        return nil if api_key.blank?

        @client ||= OpenAI::Client.new(access_token: api_key)
      end

      def parse_intent_response(response)
        content = response.dig("choices", 0, "message", "content")
        return error_response("No response content received") if content.blank?

        parsed = JSON.parse(content)
        {
          "function" => parsed["function"] || "unknown",
          "params" => parsed["params"] || {},
          "confidence" => parsed["confidence"] || 0.0
        }
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
        error_response("Failed to parse intent response")
      end

      def error_response(message)
        {
          "function" => "error",
          "params" => {},
          "confidence" => 0.0,
          "error" => message
        }
      end
    end
  end
end
