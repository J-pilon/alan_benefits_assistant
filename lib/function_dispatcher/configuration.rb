module FunctionDispatcher
  class Configuration
    attr_accessor :enabled_functions, :yaml_file_path, :strict_validation, :context_required

    def initialize
      @enabled_functions = :all
      @yaml_file_path = Rails.root.join("config", "dispatch_functions.yml").to_s
      @strict_validation = false
      @context_required = true
    end
  end
end
