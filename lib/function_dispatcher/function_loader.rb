module FunctionDispatcher
  class FunctionLoader
    class << self
      def load_from_yaml(file_path)
        return error_result("File path cannot be blank") if file_path.blank?
        return error_result("File does not exist: #{file_path}") unless File.exist?(file_path)

        yaml_content = YAML.load_file(file_path)
        functions_array = yaml_content["functions"] || []

        function_definitions = functions_array.map { |func_hash| parse_function(func_hash) }
        success_result(function_definitions)
      rescue StandardError => e
        error_result("Failed to load functions from YAML: #{e.message}")
      end

      private

      def parse_function(function_hash)
        FunctionDefinition.new(
          name: function_hash["name"].to_sym,
          method: function_hash["method"].to_sym,
          description: function_hash["description"],
          executor: executor_for_method(function_hash["method"]),
          metadata: function_hash["metadata"] || {},
          required_params: extract_required_params(function_hash),
          optional_params: extract_optional_params(function_hash),
          param_schema: function_hash["parameters"]
        )
      end

      def extract_required_params(function_hash)
        function_hash.dig("parameters", "required") || []
      end

      def extract_optional_params(function_hash)
        properties = function_hash.dig("parameters", "properties") || {}
        required = extract_required_params(function_hash)

        properties.keys - required
      end

      def executor_for_method(method_name)
        executor_name = "#{method_name}_executor"
        class_name = executor_name.camelize
        "FunctionDispatcher::Executors::#{class_name}".constantize
      rescue NameError => e
        raise StandardError, "No executor found for method '#{method_name}': #{e.message}"
      end

      def success_result(data)
        Result.success(data)
      end

      def error_result(message)
        Result.failure(message)
      end
    end
  end
end
