# frozen_string_literal: true

module Exclaim
  module Implementations
    LET_COMPONENT = ->(config, _env, &render_child) do
      bindings = (config['bindings'] || config['$let']).to_h
      child_component = config['do']

      # This implementation passes only the configured bindings as the env for
      # the child component. As an alternative approach, it could merge the bindings
      # onto the parent env to make all values available to the child.
      render_child.call(child_component, bindings)
    end
    LET_COMPONENT.define_singleton_method(:component?) { true }
  end
end
