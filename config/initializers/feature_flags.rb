module FeatureFlags
  class << self
    def ai_chat_enabled?
      ENV.fetch("AI_CHAT_ENABLED", "true") == "true"
    end
  end
end
