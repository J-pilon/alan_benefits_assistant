module OpenaiStubHelper
  def stub_openai_determine_intent(function:, params: {}, confidence: 0.9)
    response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "function" => function,
              "params" => params,
              "confidence" => confidence
            }.to_json
          }
        }
      ]
    }

    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(response)
  end

  def stub_openai_generate_response(response_text:)
    response = {
      "choices" => [
        {
          "message" => {
            "content" => response_text
          }
        }
      ]
    }

    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(response)
  end

  def stub_openai_error(error_message: "API Error")
    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError.new(error_message))
  end

  def stub_openai_client_creation(api_key: "test-key")
    allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(api_key)
  end

  def stub_openai_missing_api_key
    allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
  end
end
