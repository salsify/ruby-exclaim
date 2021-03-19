# frozen_string_literal: true

module Exclaim
  class Bind
    attr_reader :path, :json_declaration

    def initialize(path:, json_declaration: nil)
      raise UiConfigurationError.new("$bind path must be a String, found #{path.class}") unless path.is_a?(String)

      @json_declaration = json_declaration
      self.path = path
    end

    def path=(value)
      @path = value
      @path_keys = @path.split('.')
      @path_keys_for_arrays = @path_keys.map do |string|
        Integer(string)
      rescue ArgumentError, TypeError
        string
      end
    end

    def evaluate(env)
      env.dig(*@path_keys_for_arrays) || env.dig(*@path_keys)
    end
  end
end
