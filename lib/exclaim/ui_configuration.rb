# frozen_string_literal: true

module Exclaim
  module UiConfiguration
    extend self

    EXPLICIT_ELEMENT_NAMES = ['$component', '$helper', '$bind'].freeze

    def parse!(implementation_map, ui_config)
      raise UiConfigurationError.new("ui_config must be a Hash, given: #{ui_config.class}") unless ui_config.is_a?(Hash)

      parsed_ui = parse_config_value(implementation_map, ui_config)

      unless parsed_ui.is_a?(Exclaim::Component)
        error_message = 'ui_config must declare a component at the top-level that is present in implementation_map'
        raise UiConfigurationError.new(error_message)
      end

      parsed_ui
    end

    private

    def parse_config_value(implementation_map, config_value)
      case config_value
      in Hash => hash
        parse_config_hash(implementation_map, hash)
      in Array => array
        array.map { |value| parse_config_value(implementation_map, value) }
      else
        config_value
      end
    end

    def parse_config_hash(implementation_map, config_hash)
      # config_hash will be either an Exclaim element declaration or just plain configuration values
      element_name = parse_element_name(implementation_map, config_hash)
      if element_name.nil?
        config_hash.transform_values { |val| parse_config_value(implementation_map, val) }
      else
        parse_element(implementation_map, element_name, config_hash)
      end
    end

    def parse_element(implementation_map, element_name, element_declaration_hash)
      implementation = implementation_map[element_name]

      if helper?(implementation)
        config = parse_element_config(implementation_map, element_declaration_hash)
        Exclaim::Helper.new(json_declaration: element_declaration_hash,
                            name: element_name,
                            implementation: implementation,
                            config: config)
      elsif component?(implementation)
        config = parse_element_config(implementation_map, element_declaration_hash)
        Exclaim::Component.new(json_declaration: element_declaration_hash,
                               name: element_name,
                               implementation: implementation,
                               config: config)
      else
        Exclaim::Bind.new(json_declaration: element_declaration_hash, path: element_declaration_hash['$bind'])
      end
    end

    def parse_element_config(implementation_map, element_declaration_hash)
      element_declaration_hash.each_with_object({}) do |(key, val), parsed_element_config|
        parsed_element_config[key] = if ['$component', '$helper'].include?(key)
                                       val
                                     else
                                       parse_config_value(implementation_map, val)
                                     end
      end
    end

    def parse_element_name(implementation_map, config_hash)
      candidate_names = config_hash.keys.filter_map do |key|
        key[1..] if key.start_with?('$') && !EXPLICIT_ELEMENT_NAMES.include?(key)
      end
      candidate_names.reject! do |name|
        unrecognized = implementation_map[name].nil?
        Exclaim.logger.warn("ui_config includes key \"$#{name}\" which has no matching implementation") if unrecognized
        unrecognized
      end

      explicit_component_name = parse_explicit_declaration(implementation_map, config_hash, '$component')
      explicit_helper_name = parse_explicit_declaration(implementation_map, config_hash, '$helper')

      candidate_names.push(explicit_component_name, explicit_helper_name)
      candidate_names.compact!

      # binds do not have implementations, but they are still special Exclaim elements
      candidate_names.push('bind') if config_hash.include?('$bind')

      if candidate_names.count > 1
        error_message = "Multiple Exclaim elements defined at one configuration level: #{candidate_names}. " \
                        'Only one allowed.'
        raise UiConfigurationError.new(error_message)
      end

      # returns nil when config_hash is not an Exclaim element declaration
      candidate_names.first
    end

    def parse_explicit_declaration(implementation_map, config_hash, explicit_key)
      explicit_name = config_hash[explicit_key]
      return nil if explicit_name.nil?

      if explicit_name.start_with?('$')
        error_message = "Invalid: \"#{explicit_key}\": \"#{explicit_name}\", " \
                        "when declaring explicit \"#{explicit_key}\" do not prefix the name with \"$\""
        raise UiConfigurationError.new(error_message)
      end

      if implementation_map[explicit_name].nil?
        error_message = "ui_config declares \"#{explicit_key}\": \"#{explicit_name}\" " \
                        'which has no matching implementation'
        raise UiConfigurationError.new(error_message)
      end

      explicit_name
    end

    def component?(element)
      element_type(element) == 'component'
    end

    def helper?(element)
      element_type(element) == 'helper'
    end

    def element_type(element)
      if element.respond_to?(:component?)
        element.component? ? 'component' : 'helper'
      elsif element.respond_to?(:helper?)
        element.helper? ? 'helper' : 'component'
      end
    end
  end
end
