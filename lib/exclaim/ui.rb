# frozen_string_literal: true

module Exclaim
  class Ui
    attr_reader :implementation_map, :parsed_ui

    def initialize(implementation_map: Exclaim::Implementations.example_implementation_map)
      @implementation_map = Exclaim::ImplementationMap.parse!(implementation_map)
    rescue Exclaim::Error
      raise
    rescue StandardError => e
      e.extend(Exclaim::InternalError)
      raise
    end

    def parse_ui!(ui_config)
      self.parsed_ui = Exclaim::UiConfiguration.parse!(@implementation_map, ui_config)
    rescue Exclaim::Error
      raise
    rescue StandardError => e
      e.extend(Exclaim::InternalError)
      raise
    end

    private

    def parsed_ui=(value)
      @parsed_ui = value
    end
  end
end
