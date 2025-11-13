module PiiRedaction
  class Configuration
    attr_accessor :default_placeholder_format, :locale, :enabled_patterns
    attr_reader :custom_patterns

    def initialize
      @default_placeholder_format = "[%s_REDACTED]"
      @locale = :en_us
      @enabled_patterns = :all
      @custom_patterns = {}
    end

    def register_pattern(key, pattern:, redactor: nil, priority: 50, metadata: {})
      @custom_patterns[key] = PatternDefinition.new(key:, pattern:, redactor:, priority:, metadata:)
    end

    def unregister_pattern(key)
      @custom_patterns.delete(key)
    end
  end
end
