module PiiRedaction
  class PatternRegistry
    def initialize
      @patterns = {}
      register_default_patterns
    end

    def register(pattern_definition)
      @patterns[pattern_definition.key] = pattern_definition
    end

    def unregister(key)
      @patterns.delete(key)
    end

    def get(key)
      @patterns[key]
    end

    def all
      @patterns.values
    end

    def for_locale(locale)
      @patterns.values.select do |pattern|
        pattern.metadata[:locale].nil? ||
        pattern.metadata[:locale] == locale ||
        pattern.metadata[:locale] == :all
      end
    end

    def sorted_by_priority
      @patterns.values.sort_by(&:priority)
    end

    private

    def register_default_patterns
      # Email - universal
      register(PatternDefinition.new(
        key: :email,
        pattern: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,
        priority: 10,
        metadata: { locale: :all, category: :contact, description: "Email addresses" }
      ))

      # Credit card - universal
      register(PatternDefinition.new(
        key: :credit_card,
        pattern: /\b(?:\d{4}[-\s]?){3}\d{4}\b/,
        priority: 15,
        metadata: { locale: :all, category: :financial, severity: :high }
      ))

      # Canadian SIN
      register(PatternDefinition.new(
        key: :sin,
        pattern: /\b\d{3}[-.\s]?\d{3}[-.\s]?\d{3}\b/,
        priority: 16,
        metadata: { locale: :en_ca, category: :government_id, severity: :high }
      ))

      # US SSN
      register(PatternDefinition.new(
        key: :ssn,
        pattern: /\b\d{3}[-.\s]?\d{2}[-.\s]?\d{4}\b/,
        priority: 16,
        metadata: { locale: :en_us, category: :government_id, severity: :high }
      ))

      # Phone numbers
      register(PatternDefinition.new(
        key: :phone,
        pattern: /\b(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b/,
        redactor: Redactors::PhoneRedactor,
        priority: 20,
        metadata: { locale: :all, category: :contact }
      ))

      # Canadian postal code
      register(PatternDefinition.new(
        key: :postal_code_ca,
        pattern: /\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b/i,
        priority: 25,
        metadata: { locale: :en_ca, category: :location }
      ))

      # US ZIP code
      register(PatternDefinition.new(
        key: :zip_code,
        pattern: /\b\d{5}(?:-\d{4})?\b/,
        priority: 25,
        metadata: { locale: :en_us, category: :location }
      ))

      # Address
      register(PatternDefinition.new(
        key: :address,
        pattern: /\b\d+\s+[A-Z][a-z]+(?:\s+(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd|Court|Ct|Place|Pl|Way|Circle|Cir|Blvd|Crescent|Cres|Terrace|Terr))\b/i,
        priority: 30,
        metadata: { locale: :all, category: :location }
      ))

      # Date
      register(PatternDefinition.new(
        key: :date,
        pattern: /\b(?:\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}|\d{4}[-\/]\d{1,2}[-\/]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4})\b/i,
        priority: 35,
        metadata: { locale: :all, category: :temporal }
      ))

      # Name (requires special redactor)
      register(PatternDefinition.new(
        key: :name,
        pattern: /(?:(?:^|\.\s+)(?!My|The|A|An|I|Name|This|That|These|Those|Contact|Postal|Email|Phone|Address|Date|Reset|Vision|Coverage|Massage|Dental|Hello|Hi|Hey|Greetings|Welcome)([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,2})\b|(?:name is|I am|called|known as|Mr\.|Mrs\.|Ms\.|Dr\.)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,2})\b)/i,
        redactor: Redactors::NameRedactor,
        priority: 40,
        metadata: { locale: :all, category: :identity }
      ))

      # URL
      register(PatternDefinition.new(
        key: :url,
        pattern: /\b(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b[-a-zA-Z0-9()@:%_\+.~#?&\/=]*/i,
        priority: 12,
        metadata: { locale: :all, category: :contact }
      ))

      # IP Address
      register(PatternDefinition.new(
        key: :ip_address,
        pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/,
        priority: 13,
        metadata: { locale: :all, category: :technical }
      ))
    end
  end
end
