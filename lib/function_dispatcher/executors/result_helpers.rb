module FunctionDispatcher
  module Executors
    module ResultHelpers
      def success_result(data)
        {
          success: true,
          data: data
        }
      end

      def error_result(message)
        {
          success: false,
          error: message
        }
      end
    end
  end
end
