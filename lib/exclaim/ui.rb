# frozen_string_literal: true

module Exclaim
  class Ui
    attr_reader :implementation_map, :parsed_ui, :renderer

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

    def render(env: {})
      if parsed_ui.nil?
        error_message = 'Cannot render without UI configured, must call Exclaim::Ui#parse_ui(ui_config) first'
        raise RenderingError.new(error_message)
      end

      renderer.call(env: env)
    rescue Exclaim::Error
      raise
    rescue StandardError => e
      e.extend(Exclaim::InternalError)
      raise
    end

    def unique_bind_paths
      if parsed_ui.nil?
        error_message = 'Cannot compute unique_bind_paths without UI configured, ' \
                        'must call Exclaim::Ui#parse_ui(ui_config) first'
        raise UiConfigurationError.new(error_message)
      end

      parsed_ui.config.reduce([]) { |all_paths, config_value| bind_paths(config_value, all_paths) }.uniq!
    end

    def each_element(element_names = :ALL_ELEMENTS, &blk)
      if parsed_ui.nil?
        error_message = 'Cannot compute each_element without UI configured, ' \
                        'must call Exclaim::Ui#parse_ui(ui_config) first'
        raise UiConfigurationError.new(error_message)
      end
      normalized_element_names = parse_element_names(element_names)

      if block_given?
        top_level_component = parsed_ui
        recurse_json_declarations(top_level_component, normalized_element_names, &blk)
      else
        to_enum(__callee__)
      end
    end

    private

    def parsed_ui=(value)
      @parsed_ui = value
      @renderer = Exclaim::Renderer.new(@parsed_ui)
    end

    def bind_paths(config_value, accumulator)
      case config_value
      in Hash => hash
        hash.values.each { |val| bind_paths(val, accumulator) }
      in Array => array
        array.each { |val| bind_paths(val, accumulator) }
      in Bind => bind
        accumulator.push(bind.path)
      in Helper | Component => element
        bind_paths(element.config, accumulator)
      else
        nil
      end

      accumulator
    end

    def parse_element_names(element_names)
      case element_names
      when :ALL_ELEMENTS
        :ALL_ELEMENTS
      when String
        [normalize_name(element_names)]
      when Array
        element_names.map { |en| normalize_name(en) }
      else
        raise UiConfigurationError.new('Exclaim::Ui#each_element: element_names argument ' \
                                       "must be a String or Array, given #{element_names.class}")
      end
    end

    def normalize_name(element_name)
      element_name.start_with?('$') ? element_name[1..] : element_name
    end

    def recurse_json_declarations(config_value, element_names, &blk)
      case config_value
      in Bind => bind
        yield bind.json_declaration if element_matches?(element_names, 'bind')
      in Component | Helper => element
        yield element.json_declaration if element_matches?(element_names, element.name)
        element.config.each_value { |val| recurse_json_declarations(val, element_names, &blk) }
      in Array => array
        array.each { |val| recurse_json_declarations(val, element_names, &blk) }
      in Hash => hash
        hash.each_value { |val| recurse_json_declarations(val, element_names, &blk) }
      else
        nil
      end
    end

    def element_matches?(requested_element_names, parsed_element_name)
      requested_element_names == :ALL_ELEMENTS || requested_element_names.include?(parsed_element_name)
    end
  end
end
