module PiiRedaction
  class Service
    attr_reader :config, :registry

    def initialize(config: nil, registry: nil)
      @config = config || Configuration.new
      @registry = registry || PatternRegistry.new

      @config.custom_patterns.values.each do |pattern_def|
        @registry.register(pattern_def)
      end
    end

    def redact(text, placeholder_format: nil)
      return text if text.blank?

      placeholder_format ||= @config.default_placeholder_format

      patterns_to_use = if @config.enabled_patterns == :all
        patterns_for_current_locale
      else
        patterns_for_current_locale.select do |pattern|
          @config.enabled_patterns.include?(pattern.key)
        end
      end

      redacted_text = text.dup
      patterns_to_use.sort_by(&:priority).each do |pattern_def|
        redacted_text = pattern_def.redact(redacted_text, placeholder_format)
      end

      redacted_text
    end

    def contains_pii?(text)
      return false if text.blank?

      patterns_to_use = @registry.for_locale(@config.locale)
      patterns_to_use.any? { |pattern_def| pattern_def.pattern.match?(text) }
    end

    def detect_pii_types(text)
      return [] if text.blank?

      patterns_to_use = @registry.for_locale(@config.locale)
      patterns_to_use.select { |pattern_def| pattern_def.pattern.match?(text) }
                     .map(&:key)
    end

    def detect_pii_with_metadata(text)
      return [] if text.blank?

      patterns_to_use = @registry.for_locale(@config.locale)
      patterns_to_use.select { |pattern_def| pattern_def.pattern.match?(text) }
                     .map { |pattern_def| { key: pattern_def.key, metadata: pattern_def.metadata } }
    end

    private

    def patterns_for_current_locale
      @registry.for_locale(@config.locale)
    end
  end
end
