require 'rails_helper'

RSpec.describe SupportService do
  let(:profile) { create(:profile) }
  let(:user_message) { "How much massage coverage do I have left?" }
  let(:mock_ai_service) { double("AiService") }

  let(:service) do
    described_class.new(profile: profile, ai_service: mock_ai_service)
  end

  describe '#process_user_query' do
    context 'with valid user_message' do
      context 'when ai_chat_enabled? is true' do
        let(:ai_result) do
          Result.success(
            function: "coverage_balances_read",
            params: { "category" => "massage" },
            intent_confidence: 0.95,
            function_result: { "remaining_amount" => 500.00 },
            response: "You have $500 remaining in your massage coverage.",
            response_confidence: 0.85
          )
        end

        before do
          allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(true)
          allow(mock_ai_service).to receive(:process_query).and_return(ai_result)
        end

        it 'calls process_query on AiService with user_message and profile' do
          service.process_user_query(user_message)

          expect(mock_ai_service).to have_received(:process_query).with(
            user_message,
            profile: profile
          )
        end

        it 'creates a chat_message record' do
          expect {
            service.process_user_query(user_message)
          }.to change { profile.chat_messages.count }.by(1)

          chat_message = profile.chat_messages.last
          expect(chat_message.user_message).to eq(user_message)
          expect(chat_message.ai_response).to eq("You have $500 remaining in your massage coverage.")
          expect(chat_message.ai_metadata["source"]).to eq("ai")
          expect(chat_message.ai_metadata["function"]).to eq("coverage_balances_read")
          expect(chat_message.ai_metadata["intent_confidence"]).to eq(0.95)
          expect(chat_message.ai_metadata["response_confidence"]).to eq(0.85)
        end

        it 'returns success_response with correct structure' do
          result = service.process_user_query(user_message)

          expect(result[:success]).to be true
          expect(result[:source]).to eq(:ai)
          expect(result[:chat_message]).to include(
            user_message: user_message,
            ai_response: "You have $500 remaining in your massage coverage."
          )
          expect(result[:chat_message]).to have_key(:id)
          expect(result[:chat_message]).to have_key(:created_at)
          expect(result).not_to have_key(:support_ticket)
        end

        it 'does not create a support_ticket record' do
          expect {
            service.process_user_query(user_message)
          }.not_to change { profile.support_tickets.count }
        end

        context 'when AI returns a failure result' do
          let(:ai_failure_result) do
            Result.failure("AI processing failed")
          end

          before do
            allow(mock_ai_service).to receive(:process_query).and_return(ai_failure_result)
          end

          it 'returns the failure result directly' do
            result = service.process_user_query(user_message)

            expect(result).to eq(ai_failure_result)
            expect(result.failure?).to be true
            expect(result.error).to eq("AI processing failed")
          end

          it 'does not create a chat_message record' do
            expect {
              service.process_user_query(user_message)
            }.not_to change { profile.chat_messages.count }
          end
        end
      end

      context 'when ai_chat_enabled? is false' do
        before do
          allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(false)
        end

        it 'creates a chat_message record with support ticket response' do
          expect {
            service.process_user_query(user_message)
          }.to change { profile.chat_messages.count }.by(1)

          chat_message = profile.chat_messages.last
          expect(chat_message.user_message).to eq(user_message)
          expect(chat_message.ai_response).to include("Our AI assistant is temporarily unavailable")
          expect(chat_message.ai_response).to include("support ticket")
          expect(chat_message.ai_metadata["source"]).to eq("support_ticket")
          expect(chat_message.ai_metadata["feature_flag_disabled"]).to be true
        end

        it 'creates a support_ticket record' do
          expect {
            service.process_user_query(user_message)
          }.to change { profile.support_tickets.count }.by(1)

          support_ticket = profile.support_tickets.last
          expect(support_ticket.user_question).to eq(user_message)
          expect(support_ticket.status).to eq("pending")
          expect(support_ticket.priority).to eq("normal")
        end

        it 'associates the support_ticket with the chat_message' do
          result = service.process_user_query(user_message)

          support_ticket = profile.support_tickets.last
          chat_message = profile.chat_messages.last
          expect(support_ticket.chat_message).to eq(chat_message)
        end

        it 'returns success_response with correct structure' do
          result = service.process_user_query(user_message)

          expect(result[:success]).to be true
          expect(result[:source]).to eq(:support_ticket)
          expect(result[:chat_message]).to include(
            user_message: user_message
          )
          expect(result[:support_ticket]).to include(
            status: "pending",
            priority: "normal"
          )
          expect(result[:support_ticket]).to have_key(:id)
        end

        it 'does not call AiService' do
          allow(mock_ai_service).to receive(:process_query)

          service.process_user_query(user_message)

          expect(mock_ai_service).not_to have_received(:process_query)
        end

        context 'with urgent priority keywords' do
          let(:urgent_message) { "URGENT: I need help immediately!" }

          it 'sets priority to urgent' do
            service.process_user_query(urgent_message)

            support_ticket = profile.support_tickets.last
            expect(support_ticket.priority).to eq("urgent")
          end
        end

        context 'with high priority keywords' do
          let(:high_priority_message) { "This is an important problem I need help with" }

          it 'sets priority to high' do
            service.process_user_query(high_priority_message)

            support_ticket = profile.support_tickets.last
            expect(support_ticket.priority).to eq("high")
          end
        end

        context 'with normal priority message' do
          let(:normal_message) { "Can you help me understand my benefits?" }

          it 'sets priority to normal' do
            service.process_user_query(normal_message)

            support_ticket = profile.support_tickets.last
            expect(support_ticket.priority).to eq("normal")
          end
        end
      end
    end

    context 'when StandardError occurs' do
      let(:error_message) { "Database connection failed" }

      before do
        allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(true)
        allow(mock_ai_service).to receive(:process_query).and_raise(StandardError.new(error_message))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error' do
        service.process_user_query(user_message)

        expect(Rails.logger).to have_received(:error).with(a_string_including("SupportService error"))
        expect(Rails.logger).to have_received(:error).with(a_string_including(error_message))
      end

      it 'creates a support_ticket record with error context' do
        expect {
          service.process_user_query(user_message)
        }.to change { profile.support_tickets.count }.by(1)

        support_ticket = profile.support_tickets.last
        expect(support_ticket.user_question).to eq(user_message)
        expect(support_ticket.status).to eq("pending")

        initial_context = JSON.parse(support_ticket.initial_context)
        expect(initial_context["error"]).to eq(error_message)
        expect(initial_context["created_via"]).to eq("chat_interface")
      end

      it 'creates a chat_message with error in metadata' do
        expect {
          service.process_user_query(user_message)
        }.to change { profile.chat_messages.count }.by(1)

        chat_message = profile.chat_messages.last
        expect(chat_message.user_message).to eq(user_message)
        expect(chat_message.ai_response).to include("support ticket")
        expect(chat_message.ai_metadata["error"]).to eq(error_message)
        expect(chat_message.ai_metadata["source"]).to eq("support_ticket")
      end

      it 'returns success_response' do
        result = service.process_user_query(user_message)

        expect(result[:success]).to be true
        expect(result[:source]).to eq(:support_ticket)
        expect(result[:chat_message]).to be_present
        expect(result[:support_ticket]).to be_present
      end

      it 'does not raise the error' do
        expect {
          service.process_user_query(user_message)
        }.not_to raise_error
      end
    end

    context 'when profile is invalid' do
      let(:invalid_service) do
        described_class.new(profile: nil, ai_service: mock_ai_service)
      end

      let(:ai_result) do
        Result.success(
          function: "coverage_balances_read",
          params: { "category" => "massage" },
          intent_confidence: 0.95,
          function_result: { "remaining_amount" => 500.00 },
          response: "You have $500 remaining in your massage coverage.",
          response_confidence: 0.85
        )
      end

      before do
        allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(true)
        allow(Rails.logger).to receive(:error)
        allow(mock_ai_service).to receive(:process_query).and_return(ai_result)
      end

      it 'raises an error when trying to create chat message with nil profile' do
        # Since profile is nil, trying to access profile.chat_messages will fail
        expect {
          invalid_service.process_user_query(user_message)
        }.to raise_error(NoMethodError, /undefined method.*for nil/)
      end
    end
  end

  describe '#initialize' do
    it 'sets the profile' do
      service = described_class.new(profile: profile)
      expect(service.profile).to eq(profile)
    end

    it 'accepts a custom ai_service' do
      service = described_class.new(profile: profile, ai_service: mock_ai_service)
      expect(service.ai_service).to eq(mock_ai_service)
    end

    it 'creates a default AiService if none provided' do
      service = described_class.new(profile: profile)
      expect(service.ai_service).to be_an_instance_of(AiService)
    end
  end

  describe 'private methods' do
    describe '#determine_priority' do
      let(:service) { described_class.new(profile: profile) }

      it 'returns urgent for messages with urgent keywords' do
        urgent_keywords = ["urgent", "emergency", "immediately", "asap", "critical", "now"]
        urgent_keywords.each do |keyword|
          message = "This is #{keyword} please help"
          priority = service.send(:determine_priority, message)
          expect(priority).to eq("urgent"), "Expected 'urgent' for keyword '#{keyword}'"
        end
      end

      it 'returns high for messages with high priority keywords' do
        high_keywords = ["important", "soon", "quickly", "need help", "problem"]
        high_keywords.each do |keyword|
          message = "This is #{keyword}"
          priority = service.send(:determine_priority, message)
          expect(priority).to eq("high"), "Expected 'high' for keyword '#{keyword}'"
        end
      end

      it 'returns normal for messages without priority keywords' do
        message = "Just a regular question"
        priority = service.send(:determine_priority, message)
        expect(priority).to eq("normal")
      end

      it 'is case insensitive' do
        message = "URGENT: EMERGENCY situation"
        priority = service.send(:determine_priority, message)
        expect(priority).to eq("urgent")
      end
    end

    describe '#support_ticket_response' do
      let(:service) { described_class.new(profile: profile) }

      it 'returns a helpful message' do
        response = service.send(:support_ticket_response)

        expect(response).to include("support ticket")
        expect(response).to include("24 hours")
        expect(response).to include("AI assistant is temporarily unavailable")
      end
    end
  end
end
