module PiiRedaction
  module Redactors
    class DefaultRedactor
      def self.call(text, pattern, key, placeholder_format)
        placeholder = format(placeholder_format, key.to_s.upcase)
        text.gsub(pattern, placeholder)
      end
    end
  end
end
