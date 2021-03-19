# frozen_string_literal: true

module Exclaim
  module Implementations
    TEXT_COMPONENT = ->(config, _env) { config['content'] || config['$text'] }
    TEXT_COMPONENT.define_singleton_method(:component?) { true }
  end
end
