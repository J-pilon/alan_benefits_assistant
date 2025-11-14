require 'rails_helper'

RSpec.describe AiService do
  let(:profile) { create(:profile) }
  let(:user_query) { "How much massage coverage do I have left?" }
  let(:mock_intent_service) { double("IntentDeterminationService") }
  let(:mock_response_service) { double("ResponseGenerationService") }
  let(:mock_dispatcher_service) { double("FunctionDispatcher") }

  let(:service) do
    described_class.new(
      intent_service: mock_intent_service,
      response_service: mock_response_service,
      dispatcher_service: mock_dispatcher_service
    )
  end

  describe '#process_query' do
    context 'when params are valid' do
      let(:intent_result) do
        Result.success(
          function: "coverage_balances_read",
          params: { "category" => "massage" },
          confidence: 0.95
        )
      end

      let(:dispatch_result) do
        Result.success({ "remaining_amount" => 500.00, "reset_date" => "2024-12-31" })
      end

      let(:response_result) do
        Result.success(
          response: "You have $500 remaining in your massage coverage.",
          confidence: 0.85
        )
      end

      before do
        allow(mock_intent_service).to receive(:perform).and_return(intent_result)
        allow(mock_dispatcher_service).to receive(:dispatch).and_return(dispatch_result)
        allow(mock_response_service).to receive(:perform).and_return(response_result)
      end

      it 'calls intent service with user_query' do
        service.process_query(user_query, profile: profile)
        expect(mock_intent_service).to have_received(:perform).with(user_query)
      end

      it 'calls dispatch service with function, params, and context' do
        service.process_query(user_query, profile: profile)

        expect(mock_dispatcher_service).to have_received(:dispatch).with(
          "coverage_balances_read",
          params: { "category" => "massage" },
          context: { profile: profile }
        )
      end

      it 'calls response service with user_query, data, and context' do
        context = { additional: "info" }
        service.process_query(user_query, profile: profile, context: context)

        expect(mock_response_service).to have_received(:perform).with(
          user_query: user_query,
          data: { "remaining_amount" => 500.00, "reset_date" => "2024-12-31" },
          context: context
        )
      end

      it 'returns Result with all expected properties' do
        result = service.process_query(user_query, profile: profile)

        expect(result.successful?).to be true
        expect(result.data).to include(
          function: "coverage_balances_read",
          params: { "category" => "massage" },
          intent_confidence: 0.95,
          function_result: { "remaining_amount" => 500.00, "reset_date" => "2024-12-31" },
          response: "You have $500 remaining in your massage coverage.",
          response_confidence: 0.85
        )
      end
    end

    context 'when params are invalid' do
      context 'when user_query is blank' do
        it 'returns error Result for empty string' do
          result = service.process_query("", profile: profile)

          expect(result.failure?).to be true
          expect(result.error).to eq("User query cannot be blank")
        end

        it 'returns error Result for nil' do
          result = service.process_query(nil, profile: profile)

          expect(result.failure?).to be true
          expect(result.error).to eq("User query cannot be blank")
        end
      end

      context 'when profile is blank' do
        it 'returns error Result' do
          result = service.process_query(user_query, profile: nil)

          expect(result.failure?).to be true
          expect(result.error).to eq("Profile is required")
        end
      end
    end

    context 'when dependent services fail' do
      context 'when intent_service fails' do
        let(:intent_error_result) do
          Result.failure("Failed to determine intent")
        end

        it 'returns intent error Result' do
          allow(mock_intent_service).to receive(:perform).and_return(intent_error_result)

          result = service.process_query(user_query, profile: profile)

          expect(result.failure?).to be true
          expect(result).to eq(intent_error_result)
        end
      end

      context 'when the intent is not actionable' do
      let(:unknown_intent_result) do
        Result.success(
          function: "unknown",
          params: {},
          confidence: 0.3
        )
      end

        it 'returns success Result without calling dispatcher or response service' do
          allow(mock_intent_service).to receive(:perform).and_return(unknown_intent_result)
          allow(mock_dispatcher_service).to receive(:dispatch)

          result = service.process_query(user_query, profile: profile)

          expect(result.successful?).to be true
          expect(result.data[:function]).to eq("unknown")
          expect(result.data[:response]).to be_nil
          expect(mock_dispatcher_service).not_to have_received(:dispatch)
        end
      end

      context 'when dispatcher service returns an error' do
        let(:intent_result) do
          Result.success(
            function: "coverage_balances_read",
            params: { "category" => "massage" },
            confidence: 0.95
          )
        end

        let(:dispatch_error) do
          Result.failure("Database connection failed")
        end

        it 'returns error Result with error message' do
          allow(mock_intent_service).to receive(:perform).and_return(intent_result)
          allow(mock_dispatcher_service).to receive(:dispatch).and_return(dispatch_error)

          result = service.process_query(user_query, profile: profile)

          expect(result.failure?).to be true
          expect(result.error).to eq("Database connection failed")
        end
      end

      context 'when response service fails' do
        let(:intent_result) do
          Result.success(
            function: "coverage_balances_read",
            params: { "category" => "massage" },
            confidence: 0.95
          )
        end

        let(:dispatch_result) do
          Result.success({ "remaining_amount" => 500.00 })
        end

        it 'returns error Result with error message' do
          allow(mock_intent_service).to receive(:perform).and_return(intent_result)
          allow(mock_dispatcher_service).to receive(:dispatch).and_return(dispatch_result)
          allow(mock_response_service).to receive(:perform).and_raise(StandardError.new("AI timeout"))

          expect(Rails.logger).to receive(:error).with(/AI Service error/)

          result = service.process_query(user_query, profile: profile)

          expect(result.failure?).to be true
          expect(result.error).to eq("Failed to process query: AI timeout")
        end
      end
    end

    context 'when StandardError occurs' do
      it 'returns error Result object with error message' do
        allow(mock_intent_service).to receive(:perform).and_raise(StandardError.new("Unexpected error"))

        expect(Rails.logger).to receive(:error).with(/AI Service error/)

        result = service.process_query(user_query, profile: profile)

        expect(result.failure?).to be true
        expect(result.error).to eq("Failed to process query: Unexpected error")
      end
    end
  end
end
