# frozen_string_literal: true

module Exclaim
  module Implementations
    IF_HELPER = ->(config, _env) do
      # 'condition' is the shorthand property for this helper,
      # but "config['condition']" will return the falsy value nil if that key
      # does not exist in the config. That will happen when the condition is configured
      # with the shorthand property "{ '$if' => <some value> }"
      #
      # Therefore it is necessary to check for the 'condition' key to find configuration like
      # "{ 'condition' => false }" or an even explicit "{ 'condition' => nil }"
      # Then we fall back to the shorthand property if the 'condition' key does not exist.
      condition = if config.key?('condition')
                    config['condition']
                  else
                    config['$if']
                  end

      if condition
        config['then'] unless config['then'].nil?
      else
        config['else']
      end
    end
    IF_HELPER.define_singleton_method(:helper?) { true }
  end
end
