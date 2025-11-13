require_relative "function_dispatcher/configuration"
require_relative "function_dispatcher/function_definition"
require_relative "function_dispatcher/executors/get_coverage_balance_executor"
require_relative "function_dispatcher/executors/get_benefit_coverage_executor"
require_relative "function_dispatcher/function_registry"
require_relative "function_dispatcher/function_loader"
require_relative "function_dispatcher/service"

module FunctionDispatcher
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      @service = nil
    end

    def service
      @service ||= Service.new(config: configuration)
    end

    def dispatch(function_name, params: {}, context: {})
      service.dispatch(function_name, params, context)
    end

    def sanitized_function_definitions
      service.sanitized_function_definitions
    end
  end
end
