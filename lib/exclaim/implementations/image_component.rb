# frozen_string_literal: true

module Exclaim
  module Implementations
    IMAGE_COMPONENT = ->(config, _env) do
      source = config['source'] || config['$image']
      alt = config['alt']
      "<img src=\"#{source}\" alt=\"#{alt}\">"
    end
    IMAGE_COMPONENT.define_singleton_method(:component?) { true }
  end
end
