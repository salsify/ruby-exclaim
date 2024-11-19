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
    end

    def evaluate(env)
      obj = env

      @path_keys.each do |key|
        return nil if !obj.is_a?(Hash) && !obj.is_a?(Array)

        if obj.is_a?(Array)
          key = begin
            Integer(key)
          rescue ArgumentError, TypeError
            return nil
          end
        end

        obj = obj[key]
        return nil if obj.nil?
      end

      obj
    end
  end
end
