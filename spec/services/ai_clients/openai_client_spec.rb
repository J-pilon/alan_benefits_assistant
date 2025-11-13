require 'rails_helper'

RSpec.describe AiClients::OpenaiClient do
  describe '.determine_intent' do
    let(:system_prompt) { "You are a benefits assistant" }
    let(:user_prompt) { "How much massage coverage do I have?" }

    before do
      stub_openai_client_creation(api_key: "test-api-key")
    end

    context 'with valid inputs' do
      it 'returns structured JSON with function, params, and confidence' do
        stub_openai_determine_intent(
          function: "coverage_balances_read",
          params: { "category" => "massage" },
          confidence: 0.95
        )

        result = described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_successful
        expect(result.data).to be_a(Hash)
        expect(result.data["function"]).to eq("coverage_balances_read")
        expect(result.data["params"]).to eq({ "category" => "massage" })
        expect(result.data["confidence"]).to eq(0.95)
      end

      it 'calls OpenAI with correct parameters' do
        client_instance = instance_double(OpenAI::Client)
        allow(described_class).to receive(:openai_client).and_return(client_instance)

        expect(client_instance).to receive(:chat).with(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: system_prompt },
              { role: "user", content: user_prompt }
            ],
            temperature: 0.3,
            response_format: { type: "json_object" }
          }
        ).and_return({
          "choices" => [
            {
              "message" => {
                "content" => '{"function":"coverage_balances_read","params":{"category":"massage"},"confidence":0.9}'
              }
            }
          ]
        })

        described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )
      end

      it 'sets response_format to json_object' do
        client_instance = instance_double(OpenAI::Client)
        allow(described_class).to receive(:openai_client).and_return(client_instance)

        expect(client_instance).to receive(:chat).with(
          hash_including(parameters: hash_including(response_format: { type: "json_object" }))
        ).and_return({
          "choices" => [
            {
              "message" => {
                "content" => '{"function":"test","params":{},"confidence":0.9}'
              }
            }
          ]
        })

        described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )
      end
    end

    context 'with blank prompts' do
      it 'returns error response when system prompt is blank' do
        result = described_class.determine_intent(
          system_prompt: "",
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to include("System prompt cannot be blank")
      end

      it 'returns error response when user prompt is blank' do
        result = described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: ""
        )

        expect(result).to be_failure
        expect(result.error).to include("User prompt cannot be blank")
      end
    end

    context 'when API key is missing' do
      before do
        stub_openai_missing_api_key
      end

      it 'returns error response' do
        result = described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to include("OpenAI API key not configured")
      end
    end

    context 'when OpenAI API returns error' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
        stub_openai_error(error_message: "API rate limit exceeded")
      end

      it 'handles API errors gracefully' do
        result = described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to include("Failed to determine intent")
      end
    end

    context 'when OpenAI returns malformed JSON' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
        response = {
          "choices" => [
            {
              "message" => {
                "content" => "This is not valid JSON"
              }
            }
          ]
        }
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(response)
      end

      it 'handles JSON parsing errors gracefully' do
        result = described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to include("Failed to parse intent response")
      end
    end

    context 'when OpenAI returns empty content' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
        response = {
          "choices" => [
            {
              "message" => {
                "content" => nil
              }
            }
          ]
        }
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(response)
      end

      it 'handles empty content gracefully' do
        result = described_class.determine_intent(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to include("No response content received")
      end
    end
  end

  describe '.generate_response' do
    let(:system_prompt) { "You are a helpful benefits assistant" }
    let(:user_prompt) { "User Query: How much massage coverage?\n\nData: {...}" }

    before do
      stub_openai_client_creation(api_key: "test-api-key")
    end

    context 'with valid inputs' do
      it 'returns natural language response text' do
        response_text = "You have $500 remaining in your massage coverage."
        stub_openai_generate_response(response_text: response_text)

        result = described_class.generate_response(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_successful
        expect(result.data).to eq(response_text)
      end

      it 'calls OpenAI with correct parameters' do
        client_instance = instance_double(OpenAI::Client)
        allow(described_class).to receive(:openai_client).and_return(client_instance)

        expect(client_instance).to receive(:chat).with(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: system_prompt },
              { role: "user", content: user_prompt }
            ],
            temperature: 0.7
          }
        ).and_return({
          "choices" => [
            {
              "message" => {
                "content" => "Response text"
              }
            }
          ]
        })

        described_class.generate_response(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )
      end
    end

    context 'with blank prompts' do
      it 'returns fallback message when system prompt is blank' do
        result = described_class.generate_response(
          system_prompt: "",
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to eq("I'm sorry, I don't have enough information to generate a response.")
      end

      it 'returns fallback message when user prompt is blank' do
        result = described_class.generate_response(
          system_prompt: system_prompt,
          user_prompt: ""
        )

        expect(result).to be_failure
        expect(result.error).to eq("I'm sorry, I don't have enough information to generate a response.")
      end
    end

    context 'when API key is missing' do
      before do
        stub_openai_missing_api_key
      end

      it 'returns unavailable message' do
        result = described_class.generate_response(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to eq("I'm sorry, the service is temporarily unavailable.")
      end
    end

    context 'when OpenAI API returns error' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
        stub_openai_error(error_message: "API timeout")
      end

      it 'handles API errors with user-friendly message' do
        result = described_class.generate_response(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to eq("I'm sorry, I encountered an error while generating a response.")
      end
    end

    context 'when OpenAI returns missing content' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
        response = {
          "choices" => [
            {
              "message" => {
                "content" => nil
              }
            }
          ]
        }
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(response)
      end

      it 'returns fallback message' do
        result = described_class.generate_response(
          system_prompt: system_prompt,
          user_prompt: user_prompt
        )

        expect(result).to be_failure
        expect(result.error).to eq("I'm sorry, I couldn't generate a response.")
      end
    end
  end
end
