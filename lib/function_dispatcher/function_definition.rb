module FunctionDispatcher
  class FunctionDefinition
    attr_reader :name, :method, :description, :required_params,
                :optional_params, :param_schema, :executor, :metadata

    def initialize(name:, method:, description:, executor:, metadata:, required_params: [], optional_params: [], param_schema: {})
      @name = name
      @method = method
      @description = description
      @required_params = normalize_params(required_params)
      @optional_params = normalize_params(optional_params)
      @param_schema = param_schema
      @executor = executor
      @metadata = metadata
    end

    def execute(params, context: {})
      executor.call(params, context:)
    end

    def validate_params(params)
      missing = @required_params.select { |param_name|
        !params.key?(param_name) && !params.key?(param_name.to_s)
      }
      return error_result("Missing required parameters: #{missing.join(', ')}") if missing.any?

      properties = @param_schema.dig("properties") || {}
      params.each do |key, value|
        property = properties[key.to_s]
        next unless property

        enum_values = property["enum"]
        next unless enum_values

        unless enum_values.include?(value)
          return error_result("Invalid value for #{key}: must be one of #{enum_values.join(', ')}")
        end
      end

      success_result(true)
    end

    private

    def normalize_params(params)
      params.map(&:to_sym)
    end

    def success_result(data)
      Result.success(data)
    end

    def error_result(message)
      Result.failure(message)
    end
  end
end
