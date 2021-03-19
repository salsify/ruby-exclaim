# frozen_string_literal: true

module Exclaim
  module Utilities
    def element_name(config_hash)
      unless config_hash.is_a?(Hash)
        error_message = "Exclaim.element_name can only determine name from a Hash, given #{config_hash.class} value"
        Exclaim.logger.warn(error_message)
        return
      end

      return config_hash['$component'] if config_hash.include?('$component')
      return config_hash['$helper'] if config_hash.include?('$helper')
      return 'bind' if config_hash.include?('$bind')

      shorthand_name = config_hash.keys.find { |key| key.start_with?('$') }
      shorthand_name&.[](1..)
    end
  end
end
