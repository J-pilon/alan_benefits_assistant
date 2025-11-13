require 'rails_helper'

RSpec.describe ResponseGenerationService do
  let(:service) { described_class.new }

  describe '#perform' do
    let(:user_query) { "How much massage coverage do I have?" }
    let(:data) do
      {
        "category" => "massage",
        "remaining_amount" => 500.00,
        "reset_date" => "2024-12-31"
      }
    end

    context 'with valid inputs' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
      end

      it 'returns successful response generation' do
        response_text = "You have $500 remaining in your massage coverage, which resets on December 31, 2024."
        stub_openai_generate_response(response_text: response_text)

        result = service.perform(user_query: user_query, data: data)

        expect(result["response"]).to eq(response_text)
      end

      it 'includes confidence score in result' do
        stub_openai_generate_response(response_text: "You have $500 remaining.")

        result = service.perform(user_query: user_query, data: data)

        expect(result["confidence"]).to be_present
        expect(result["confidence"]).to be_a(Numeric)
        expect(result["confidence"]).to be > 0
      end

      it 'returns confidence of 0.85 for valid responses' do
        stub_openai_generate_response(response_text: "Response text")

        result = service.perform(user_query: user_query, data: data)

        expect(result["confidence"]).to eq(0.85)
      end
    end

    context 'when user_query is blank' do
      it 'returns error result for empty string' do
        result = service.perform(user_query: "", data: data)

        expect(result["response"]).to include("I'm sorry, I encountered an error")
        expect(result["confidence"]).to eq(0.0)
        expect(result["error"]).to include("User query cannot be blank")
      end

      it 'returns error result for nil' do
        result = service.perform(user_query: nil, data: data)

        expect(result["response"]).to include("I'm sorry, I encountered an error")
        expect(result["confidence"]).to eq(0.0)
        expect(result["error"]).to include("User query cannot be blank")
      end
    end

    context 'when data is blank' do
      it 'returns error result for empty hash' do
        result = service.perform(user_query: user_query, data: {})

        expect(result["response"]).to include("I'm sorry, I encountered an error")
        expect(result["confidence"]).to eq(0.0)
        expect(result["error"]).to include("Data cannot be blank")
      end

      it 'returns error result for nil' do
        result = service.perform(user_query: user_query, data: nil)

        expect(result["response"]).to include("I'm sorry, I encountered an error")
        expect(result["confidence"]).to eq(0.0)
        expect(result["error"]).to include("Data cannot be blank")
      end

      it 'returns error result for empty string' do
        result = service.perform(user_query: user_query, data: "")

        expect(result["response"]).to include("I'm sorry, I encountered an error")
        expect(result["confidence"]).to eq(0.0)
        expect(result["error"]).to include("Data cannot be blank")
      end
    end

    context 'with AI client errors' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
      end

      it 'handles AI client errors gracefully' do
        allow(AiClients::OpenaiClient).to receive(:generate_response)
          .and_raise(StandardError.new("API timeout"))

        result = service.perform(user_query: user_query, data: data)

        expect(result["response"]).to include("I'm sorry, I encountered an error")
        expect(result["confidence"]).to eq(0.0)
        expect(result["error"]).to be_present
      end

      it 'logs errors when they occur' do
        allow(AiClients::OpenaiClient).to receive(:generate_response)
          .and_raise(StandardError.new("Connection failed"))

        expect(Rails.logger).to receive(:error).with(/Response Generation error/)

        service.perform(user_query: user_query, data: data)
      end
    end

    context 'with dependency injection' do
      let(:mock_ai_client) { double("AIClient") }

      it 'uses default AI client when none provided' do
        service_default = described_class.new

        stub_openai_client_creation(api_key: "test-api-key")
        stub_openai_generate_response(response_text: "Default response")

        expect { service_default.perform(user_query: user_query, data: data) }.not_to raise_error
      end
    end

    context 'system prompt building' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
      end

      it 'builds system prompt with guidelines' do
        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:system_prompt]).to include("benefits assistant")
          expect(args[:system_prompt]).to include("clear, concise, and friendly")
          expect(args[:system_prompt]).to include("based only on the provided data")
          "Response"
        end

        service.perform(user_query: user_query, data: data)
      end

      it 'includes accuracy requirements in prompt' do
        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:system_prompt]).to include("Not make up any information")
          "Response"
        end

        service.perform(user_query: user_query, data: data)
      end
    end

    context 'user prompt building' do
      before do
        stub_openai_client_creation(api_key: "test-api-key")
      end

      it 'includes user query in prompt' do
        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:user_prompt]).to include("User Query:")
          expect(args[:user_prompt]).to include("coverage")
          "Response"
        end

        service.perform(user_query: user_query, data: data)
      end

      it 'includes data in prompt' do
        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:user_prompt]).to include("Data:")
          expect(args[:user_prompt]).to include("massage")
          expect(args[:user_prompt]).to include("500")
          "Response"
        end

        service.perform(user_query: user_query, data: data)
      end

      it 'includes context when provided' do
        context_info = "User is in Ontario province"

        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:user_prompt]).to include("Context:")
          expect(args[:user_prompt]).to include(context_info)
          "Response"
        end

        service.perform(user_query: user_query, data: data, context: context_info)
      end

      it 'omits context section when not provided' do
        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:user_prompt]).not_to include("Context:")
          "Response"
        end

        service.perform(user_query: user_query, data: data)
      end
    end
  end

  describe 'integration tests' do
    let(:user_query) { "What is my vision coverage?" }
    let(:data) do
      {
        "category" => "vision",
        "version" => "v2024-Q1-002",
        "limits" => {
          "annual_max" => 200.00,
          "frames_max" => 150.00,
          "frequency" => "every_24_months"
        }
      }
    end

    before do
      stub_openai_client_creation(api_key: "test-api-key")
    end

    context 'end-to-end with stubbed OpenAI' do
      it 'processes query and data into natural response' do
        response_text = "Your vision coverage allows up to $200 every 24 months, with up to $150 for frames."
        stub_openai_generate_response(response_text: response_text)

        result = service.perform(user_query: user_query, data: data)

        expect(result).to be_a(Hash)
        expect(result["response"]).to eq(response_text)
        expect(result["confidence"]).to eq(0.85)
      end

      it 'handles complex nested data structures' do
        complex_data = {
          "category" => "dental",
          "limits" => {
            "annual_max" => 1500.00,
            "coverage_percentage" => 80
          },
          "restrictions" => {
            "eligible_providers" => [ "Dentist", "Dental Hygienist" ],
            "exclusions" => [ "Cosmetic procedures", "Orthodontics" ]
          }
        }

        stub_openai_generate_response(response_text: "Dental coverage details...")

        result = service.perform(user_query: "What's covered for dental?", data: complex_data)

        expect(result["response"]).to be_present
        expect(result["confidence"]).to eq(0.85)
      end
    end

    context 'context parameter properly included' do
      it 'includes context in prompt when provided' do
        context_info = "Member is in Quebec with French preference"

        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:user_prompt]).to include("Context:")
          expect(args[:user_prompt]).to include(context_info)
          "Response with context"
        end

        result = service.perform(
          user_query: user_query,
          data: data,
          context: context_info
        )

        expect(result["response"]).to eq("Response with context")
      end

      it 'processes successfully without context' do
        stub_openai_generate_response(response_text: "Response without context")

        result = service.perform(user_query: user_query, data: data)

        expect(result["response"]).to eq("Response without context")
        expect(result["confidence"]).to eq(0.85)
      end

      it 'handles blank context gracefully' do
        expect(AiClients::OpenaiClient).to receive(:generate_response) do |args|
          expect(args[:user_prompt]).not_to include("Context:")
          "Response"
        end

        service.perform(user_query: user_query, data: data, context: "")
      end
    end

    context 'with real-world benefit data' do
      let(:massage_balance_data) do
        {
          "category" => "massage",
          "remaining_amount" => 350.00,
          "reset_date" => "2024-12-31",
          "rule_version_id" => "v2024-Q1-001"
        }
      end

      let(:vision_coverage_data) do
        {
          "version" => "v2024-Q1-002",
          "category" => "vision",
          "province" => "ON",
          "limits" => {
            "annual_max" => 200.00,
            "frames_max" => 150.00,
            "lenses_max" => 100.00,
            "frequency" => "every_24_months"
          },
          "restrictions" => {
            "requires_prescription" => true,
            "eligible_providers" => [ "Optometrist", "Optician" ]
          }
        }
      end

      it 'generates response for massage balance query' do
        stub_openai_generate_response(
          response_text: "You have $350 remaining in your massage coverage for this year. Your coverage resets on December 31, 2024."
        )

        result = service.perform(
          user_query: "How much massage coverage do I have left?",
          data: massage_balance_data
        )

        expect(result["response"]).to include("$350")
        expect(result["response"]).to include("massage")
        expect(result["confidence"]).to eq(0.85)
      end

      it 'generates response for vision coverage rules query' do
        stub_openai_generate_response(
          response_text: "Your vision coverage provides up to $200 every 24 months. You can get up to $150 for frames and $100 for lenses. A prescription is required."
        )

        result = service.perform(
          user_query: "What does my vision coverage include?",
          data: vision_coverage_data
        )

        expect(result["response"]).to include("$200")
        expect(result["response"]).to include("vision")
        expect(result["confidence"]).to eq(0.85)
      end
    end
  end
end
