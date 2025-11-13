module PiiRedactionHelper
  def pii_service_with_locale(locale)
    config = PiiRedaction::Configuration.new
    config.locale = locale
    PiiRedaction::Service.new(config: config)
  end

  def pii_service_with_patterns(enabled_patterns)
    config = PiiRedaction::Configuration.new
    config.enabled_patterns = enabled_patterns
    PiiRedaction::Service.new(config: config)
  end

  def pii_service_with_custom_pattern(key, pattern:, priority: 50)
    config = PiiRedaction::Configuration.new
    config.register_pattern(key, pattern: pattern, priority: priority)
    registry = PiiRedaction::PatternRegistry.new
    PiiRedaction::Service.new(config: config, registry: registry)
  end
end
