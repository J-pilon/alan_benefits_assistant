module FunctionDispatcher
  class Service
    attr_reader :registry, :config

    def initialize(registry: nil, config: nil)
      @registry = registry || FunctionRegistry.new
      @config = config || Configuration.new

      load_and_register_functions
    end

    def dispatch(function_name, params, context)
      function_name = function_name.to_sym

      function_def = @registry.get(function_name)
      return error_result("Function '#{function_name}' not found") if function_def.nil?

      unless function_enabled?(function_def)
        return error_result("Function '#{function_name}' is disabled")
      end

      validation_result = function_def.validate_params(params)
      return error_result(validation_result.error) if validation_result.failure?

      if @config.context_required && context[:profile].nil?
        return error_result("Profile context is required")
      end

      function_def.execute(params, context: context)
    rescue StandardError => e
      error_result("Execution failed: #{e.message}")
    end

    def sanitized_function_definitions
      all_function_definitions = @registry.all

      all_function_definitions.map do |func_def|
        {
          name: func_def.name,
          description: func_def.description,
          params_schema: func_def.param_schema
        }
      end
    end

    private

    def load_and_register_functions
      result = FunctionLoader.load_from_yaml(@config.yaml_file_path)
      raise StandardError, "Failed to load functions: #{result.error}" if result.failure?

      result.data.each { |function_def| @registry.register(function_def) }
    end

    def function_enabled?(function_def)
      return true if @config.enabled_functions == :all

      @config.enabled_functions.include?(function_def.name)
    end

    def error_result(message)
      Result.failure(message)
    end
  end
end
