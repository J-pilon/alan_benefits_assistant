module FunctionDispatcher
  class FunctionRegistry
    def initialize
      @functions = {}
    end

    def register(function_def)
      @functions[function_def.name] = function_def
    end

    def unregister(name)
      normalized_name = name.to_sym
      @functions.delete(normalized_name)
    end

    def get(name)
      normalized_name = name.to_sym
      @functions[normalized_name]
    end

    def all
      @functions.values
    end

    def by_category(category)
      normalized_category = category.to_sym
      @functions.values.select { |f| f.metadata[:category] == normalized_category }
    end
  end
end
