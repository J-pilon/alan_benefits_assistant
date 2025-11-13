module PiiRedaction
  module Redactors
    class NameRedactor
      def self.call(text, pattern, key, placeholder_format)
        placeholder = format(placeholder_format, key.to_s.upcase)

        text.gsub(pattern) do |match|
          md = Regexp.last_match
          name_part = md[1] || md[2] || match
          match.sub(name_part, placeholder)
        end
      end
    end
  end
end
