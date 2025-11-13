# Require all the components in dependency order
require_relative "pii_redaction/configuration"
require_relative "pii_redaction/pattern_definition"
require_relative "pii_redaction/redactors/default_redactor"
require_relative "pii_redaction/redactors/name_redactor"
require_relative "pii_redaction/redactors/phone_redactor"
require_relative "pii_redaction/pattern_registry"
require_relative "pii_redaction/service"

module PiiRedaction
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def service
      @service ||= Service.new(config: configuration)
    end

    # Convenience methods that delegate to the default service
    def redact(text, **options)
      service.redact(text, **options)
    end

    def contains_pii?(text)
      service.contains_pii?(text)
    end

    def detect_pii_types(text)
      service.detect_pii_types(text)
    end
  end
end
