module FunctionDispatcher
  module Executors
    class GetBenefitCoverageExecutor
      class << self
        def call(params, context:)
          profile = context[:profile]
          return error_result("Profile is required") if profile.nil?

          # Support both string and symbol keys
          category = params["category"] || params[:category]
          result = profile.get_benefit_coverage(category)

          if result.nil?
            error_result("No data found for category: #{category}")
          else
            success_result(result)
          end
        rescue StandardError => e
          error_result("Execution failed: #{e.message}")
        end

        private

        def success_result(data)
          Result.success(data)
        end

        def error_result(message)
          Result.failure(message)
        end
      end
    end
  end
end
