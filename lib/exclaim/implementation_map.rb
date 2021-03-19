# frozen_string_literal: true

module Exclaim
  module ImplementationMap
    extend self

    def parse!(implementation_map)
      unless implementation_map.is_a?(Hash)
        raise ImplementationMapError.new("implementation_map must be a Hash, given: #{implementation_map.class}")
      end

      implementation_map.each do |name, implementation|
        validate_name!(name)
        validate_call_params!(name, implementation)
        validate_predicate_methods!(name, implementation)
      end

      implementation_map
    end

    private

    def validate_name!(name)
      case name
      when String
        if name == ''
          raise ImplementationMapError.new('implementation name cannot be the empty String')
        elsif name.start_with?('$')
          raise ImplementationMapError.new("implementation key '#{name}' must not start with the $ symbol, " \
                                           'use the un-prefixed name')
        end
      else
        raise ImplementationMapError.new("implementation name must be a String, found: #{name.inspect}")
      end
    end

    def validate_call_params!(name, implementation)
      unless implementation.respond_to?(:call)
        raise ImplementationMapError.new("implementation for '#{name}' does not respond to call")
      end

      call_params = if implementation.respond_to?(:parameters)
                      implementation.parameters
                    else
                      implementation.method(:call).parameters
                    end
      error_message = "implementation for '#{name}' must accept two positional parameters for config and env, " \
                        "and optionally a render_child block. Actual parameters: #{call_params}"
      raise ImplementationMapError.new(error_message) unless call_params_valid?(call_params)
    end

    def call_params_valid?(call_params)
      return false unless call_params.count >= 2 && call_params.count <= 3

      call_params.each_with_index do |param, idx|
        if idx < 2
          return false unless positional_param_valid?(param)
        else
          return false unless param[0] == :block
        end
      end
    end

    def positional_param_valid?(param)
      case param
      in [:opt, _]
        true
      in [:req, _]
        true
      else
        false
      end
    end

    def validate_predicate_methods!(name, implementation)
      unless implementation.respond_to?(:component?) || implementation.respond_to?(:helper?)
        raise ImplementationMapError.new("implementation for '#{name}' must provide a " \
                                         'component? or helper? predicate method')
      end

      # if implementation defines both predicates, verify they return opposite values
      # otherwise, implementation only defines one of the predicates, so we can assume the opposite for the other
      if implementation.respond_to?(:component?) && implementation.respond_to?(:helper?)
        # use ! to coerce to booleans
        same = !implementation.component? == !implementation.helper?
        if same
          raise ImplementationMapError.new("implementation for '#{name}' must provide opposite truth values " \
                                           'for component? and helper? methods')
        end
      end
    end
  end
end
