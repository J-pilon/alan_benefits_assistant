require "openai"

module AiClients
  class OpenaiClient < AiClient
    MODEL_NAME = "gpt-4o-mini"

    class << self
      def determine_intent(system_prompt:, user_prompt:)
        return error_result("System prompt cannot be blank") if system_prompt.blank?
        return error_result("User prompt cannot be blank") if user_prompt.blank?

        begin
          response = call_openai_chat(
            system_prompt: system_prompt,
            user_prompt: user_prompt,
            temperature: 0.3,
            response_format: "json_object"
          )

          parse_response(response)
        rescue StandardError => e
          Rails.logger.error("OpenAI API error in determine_intent: #{e.message}")
          error_result("Failed to determine intent: #{e.message}")
        end
      end

      def generate_response(system_prompt:, user_prompt:)
        return error_result("I'm sorry, I don't have enough information to generate a response.") if system_prompt.blank? || user_prompt.blank?

        begin
          response = call_openai_chat(
            system_prompt: system_prompt,
            user_prompt: user_prompt,
            temperature: 0.7,
            response_format: "json_object"
          )

          parse_response(response)
        rescue StandardError => e
          Rails.logger.error("OpenAI API error in generate_response: #{e.message}")
          error_result("I'm sorry, I encountered an error while generating a response.")
        end
      end

      private

      def openai_client
        api_key = Rails.application.credentials.dig(:openai, :api_key)
        return error_result("OpenAI API key not configured") if api_key.blank?

        @client ||= OpenAI::Client.new(access_token: api_key)
      end

      def call_openai_chat(system_prompt:, user_prompt:, temperature:, response_format: nil)
        parameters = {
          model: MODEL_NAME,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt }
          ],
          temperature: temperature
        }

        parameters[:response_format] = { type: response_format } if response_format.present?

        openai_client.chat(parameters: parameters)
      end

      def parse_response(response)
        content = response.dig("choices", 0, "message", "content")
        if content.present?
          parsed_content = JSON.parse(content, symbolize_names: true)
          success_result(parsed_content)
        else
          error_result("I'm sorry, I couldn't generate a response.")
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
        error_result("Failed to parse OpenAI response: #{e.message}")
      end

      def success_result(data)
        Result.success(data)
      end

      def error_result(message)
        Result.failure(message)
      end
    end
  end
end
