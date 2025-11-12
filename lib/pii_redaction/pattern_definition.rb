module PiiRedaction
  class PatternDefinition
    attr_reader :key, :pattern, :redactor, :priority, :metadata

    def initialize(key:, pattern:, redactor: nil, priority: 50, metadata: {})
      @key = key
      @pattern = pattern
      @redactor = redactor || default_redactor
      @priority = priority
      @metadata = metadata
    end

    def redact(text, placeholder_format)
      redactor.call(text, pattern, key, placeholder_format)
    end

    private

    def default_redactor
      Redactors::DefaultRedactor
    end
  end
end
