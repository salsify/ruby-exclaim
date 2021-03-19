# frozen_string_literal: true

module Exclaim
  class Ui
    attr_reader :implementation_map

    def initialize(implementation_map: Exclaim::Implementations.example_implementation_map)
      @implementation_map = Exclaim::ImplementationMap.parse!(implementation_map)
    rescue Exclaim::Error
      raise
    rescue StandardError => e
      e.extend(Exclaim::InternalError)
      raise
    end
  end
end
