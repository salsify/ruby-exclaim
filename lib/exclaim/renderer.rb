# frozen_string_literal: true

module Exclaim
  class Renderer
    def initialize(parsed_ui, should_escape_html = true)
      @parsed_ui = parsed_ui
      @should_escape_html = should_escape_html
    end

    def call(env: {})
      top_level_component = @parsed_ui
      render_element(top_level_component, env)
    end

    private

    def render_element(element, env)
      case element
      in Component => component
        resolved_config = resolve_component_config(component, env)
        render_child = method(:render_element)
        component.implementation.call(resolved_config, env, &render_child)
      else
        resolve(element, env)
      end
    end

    def resolve_component_config(component, env)
      resolve(component.config, env).transform_values! { |value| @should_escape_html ? escape_html!(value) : value }
    end

    def escape_html!(value)
      case value
      when String
        CGI.escape_html(value)
      when Hash
        value.transform_values! { |v| escape_html!(v) }
      when Array
        value.map! { |v| escape_html!(v) }
      when Numeric, TrueClass, FalseClass, NilClass
        value
      else
        # assumed to be a custom wrapper class returned by a helper
        value
      end
    end

    def resolve(element, env)
      case element
      in Component => component
        component # will be resolved by calling its implementation later
      in Bind => bind
        bind.evaluate(env)
      in Helper => helper
        resolved_helper_config = resolve(helper.config, env)
        helper.implementation.call(resolved_helper_config, env)
      in Hash => hash
        hash.transform_values { |value| resolve(value, env) }
      in Array => array
        array.map { |item| resolve(item, env) }
      else
        element
      end
    end
  end
end
