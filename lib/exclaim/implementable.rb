# frozen_string_literal: true

module Exclaim
  module Implementable
    attr_accessor :json_declaration, :name, :implementation, :config

    def initialize(json_declaration: nil, name: nil, implementation: ->(_config, _env) { nil }, config: {})
      @json_declaration = json_declaration
      @name = name
      @implementation = implementation
      @config = config
    end
  end
end
