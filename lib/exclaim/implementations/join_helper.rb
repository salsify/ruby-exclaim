# frozen_string_literal: true

module Exclaim
  module Implementations
    JOIN_HELPER = ->(config, _env) do
      items = (config['items'] || config['$join']).to_a
      separator = config['separator'] || ''
      items.join(separator)
    end
    JOIN_HELPER.define_singleton_method(:helper?) { true }
  end
end
