module AiClients
  class AiClient
    class << self
      def determine_intent(sanitized_prompt, functions:)
        raise NotImplementedError, "#{self.class} must implement #determine_intent"
      end

      def generate_response(data, context = nil)
        raise NotImplementedError, "#{self.class} must implement #generate_response"
      end
    end
  end
end
