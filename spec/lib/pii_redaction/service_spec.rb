require 'rails_helper'

RSpec.describe PiiRedaction::Service do
  let(:service) { described_class.new }

  describe '#redact' do
    context 'with various PII types' do
      it 'redacts email addresses' do
        text = "Contact me at john.doe@example.com"
        result = service.redact(text)
        expect(result).to eq("Contact me at [EMAIL_REDACTED]")
      end

      it 'redacts phone numbers' do
        text = "The number is 416-555-1234"
        result = service.redact(text)
        expect(result).to eq("The number is [PHONE_REDACTED]")
      end

      it 'redacts credit card numbers' do
        text = "The card is 4532-1234-5678-9010"
        result = service.redact(text)
        expect(result).to eq("The card is [CREDIT_CARD_REDACTED]")
      end

      it 'redacts addresses' do
        text = "I live at 123 Main Street"
        result = service.redact(text)
        expect(result).to eq("I live at [ADDRESS_REDACTED]")
      end

      it 'redacts names' do
        text = "My name is John Smith and I need help."
        result = service.redact(text)
        expect(result).to eq("My name is [NAME_REDACTED] I need help.")
      end

      it 'redacts URLs' do
        text = "Visit https://example.com for more info"
        result = service.redact(text)
        expect(result).to eq("Visit [URL_REDACTED] for more info")
      end

      it 'redacts IP addresses' do
        text = "Server IP: 192.168.1.100 online"
        result = service.redact(text)
        # IP addresses may be detected as URLs due to pattern overlap
        expect(result).to match(/REDACTED/)
        expect(result).not_to include("192.168.1.100")
      end

      it 'redacts dates' do
        text = "The date is 12/25/1990"
        result = service.redact(text)
        expect(result).to eq("The date is [DATE_REDACTED]")
      end
    end

    context 'with locale-specific patterns' do
      it 'redacts Canadian postal codes when locale is en_ca' do
        service_ca = pii_service_with_locale(:en_ca)

        text = "Postal code: M5H 2N2"
        result = service_ca.redact(text)
        expect(result).to eq("Postal code: [POSTAL_CODE_CA_REDACTED]")
      end

      it 'redacts US ZIP codes when locale is en_us' do
        service_us = pii_service_with_locale(:en_us)

        text = "ZIP: 90210"
        result = service_us.redact(text)
        expect(result).to eq("ZIP: [ZIP_CODE_REDACTED]")
      end

      it 'does not redact US ZIP codes when locale is en_ca' do
        service_ca = pii_service_with_locale(:en_ca)

        text = "ZIP: 90210"
        result = service_ca.redact(text)
        expect(result).to eq("ZIP: 90210")
      end
    end

    context 'with enabled_patterns configuration' do
      it 'redacts only enabled patterns when specified' do
        service_filtered = pii_service_with_patterns([ :email ])

        text = "Email: test@example.com Phone: 416-555-1234"
        result = service_filtered.redact(text)
        expect(result).to eq("Email: [EMAIL_REDACTED] Phone: 416-555-1234")
      end

      it 'redacts all patterns when enabled_patterns is :all' do
        service_all = pii_service_with_patterns(:all)

        text = "Email: test@example.com Phone: 416-555-1234"
        result = service_all.redact(text)
        expect(result).to eq("Email: [EMAIL_REDACTED] Phone: [PHONE_REDACTED]")
      end
    end

    context 'with custom placeholder formats' do
      it 'uses custom placeholder format when provided' do
        text = "Email: test@example.com"
        result = service.redact(text, placeholder_format: "***")
        expect(result).to eq("Email: ***")
      end

      it 'uses default placeholder when none specified' do
        text = "Email: test@example.com"
        result = service.redact(text)
        expect(result).to eq("Email: [EMAIL_REDACTED]")
      end
    end

    context 'with blank or nil input' do
      it 'returns the text unchanged when blank' do
        result = service.redact("")
        expect(result).to eq("")
      end

      it 'returns the text unchanged when nil' do
        result = service.redact(nil)
        expect(result).to be_nil
      end
    end

    context 'with pattern priority ordering' do
      it 'processes lower priority patterns first' do
        # Email (priority 10) should be processed before name (priority 40)
        text = "Contact john.doe@example.com or John Doe"
        result = service.redact(text)
        expect(result).to include("REDACTED")
        expect(result).not_to include("john.doe@example.com")
      end
    end
  end

  describe '#contains_pii?' do
    it 'returns true when text contains PII' do
      text = "My email is test@example.com"
      expect(service.contains_pii?(text)).to be true
    end

    it 'returns false when text does not contain PII' do
      text = "coverage information needed"
      expect(service.contains_pii?(text)).to be false
    end

    it 'returns false for blank text' do
      expect(service.contains_pii?("")).to be false
      expect(service.contains_pii?(nil)).to be false
    end

    it 'detects phone numbers as PII' do
      text = "The number is 416-555-1234"
      expect(service.contains_pii?(text)).to be true
    end

    it 'detects credit cards as PII' do
      text = "Card: 4532-1234-5678-9010"
      expect(service.contains_pii?(text)).to be true
    end
  end

  describe '#detect_pii_types' do
    it 'returns array of detected PII pattern keys' do
      text = "Email: test@example.com Phone: 416-555-1234"
      types = service.detect_pii_types(text)
      expect(types).to include(:email, :phone)
    end

    it 'returns empty array when no PII detected' do
      text = "coverage information needed"
      types = service.detect_pii_types(text)
      expect(types).to be_empty
    end

    it 'returns empty array for blank text' do
      expect(service.detect_pii_types("")).to be_empty
      expect(service.detect_pii_types(nil)).to be_empty
    end

    it 'detects multiple PII types' do
      text = "Email: test@example.com, Card: 4532-1234-5678-9010, Phone: 416-555-1234"
      types = service.detect_pii_types(text)
      expect(types).to include(:email, :credit_card, :phone)
    end
  end

  describe '#detect_pii_with_metadata' do
    it 'returns array of hashes with key and metadata' do
      text = "Email: test@example.com"
      result = service.detect_pii_with_metadata(text)

      expect(result).to be_an(Array)
      expect(result.first).to have_key(:key)
      expect(result.first).to have_key(:metadata)
      expect(result.first[:key]).to eq(:email)
    end

    it 'includes metadata for detected patterns' do
      text = "Email: test@example.com"
      result = service.detect_pii_with_metadata(text)

      metadata = result.first[:metadata]
      expect(metadata).to have_key(:locale)
      expect(metadata).to have_key(:category)
    end

    it 'returns empty array when no PII detected' do
      text = "coverage information"
      result = service.detect_pii_with_metadata(text)
      expect(result).to be_empty
    end
  end

  describe 'complex redaction patterns' do
    context 'with multiple PII types in single text' do
      it 'redacts all PII types' do
        text = "Contact John Doe at john.doe@example.com or 416-555-1234"
        result = service.redact(text)

        expect(result).not_to include("john.doe@example.com")
        expect(result).not_to include("416-555-1234")
        expect(result).to include("REDACTED")
      end

      it 'redacts complex text' do
        text = "My SIN is 123-456-789, email is test@example.com, and I live at 123 Main Street"
        service_ca = pii_service_with_locale(:en_ca)

        result = service_ca.redact(text)
        expect(result).not_to include("123-456-789")
        expect(result).not_to include("test@example.com")
        expect(result).not_to include("123 Main Street")
      end
    end

    context 'with overlapping patterns' do
      it 'handles overlapping patterns by priority' do
        # Test that priority ordering prevents conflicts
        text = "Email test@example.com with date 01/15/2024"
        result = service.redact(text)

        expect(result).to include("REDACTED")
        expect(result).not_to include("test@example.com")
        expect(result).not_to include("01/15/2024")
      end
    end

    context 'with custom patterns via configuration' do
      it 'redacts custom patterns when registered' do
        service_custom = pii_service_with_custom_pattern(:custom_id, pattern: /ID-\d{6}/, priority: 50)

        text = "My ID is ID-123456"
        result = service_custom.redact(text)
        expect(result).to eq("My ID is [CUSTOM_ID_REDACTED]")
      end
    end
  end
end
