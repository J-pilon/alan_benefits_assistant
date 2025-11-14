FunctionDispatcher.configure do |config|
  config.enabled_functions = :all
  config.yaml_file_path = Rails.root.join("config", "dispatch_functions.yml").to_s
end
