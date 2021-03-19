# frozen_string_literal: true

module Exclaim
  module Implementations
    INDENT = '  '

    VBOX_COMPONENT = ->(config, env, &render_child) do
      first_line = '<div style="display: flex; flex-flow: column">'
      child_elements = (config['children'] || config['$vbox']).to_a
      child_lines = child_elements.flat_map do |child|
        result = render_child.call(child, env)
        result.lines.map { |line| "#{INDENT}#{line}" }
      end
      last_line = '</div>'

      # ensure each line ends with at least one newline to produce readable HTML
      lines = [first_line, *child_lines, last_line]
      lines.map { |line| line.end_with?("\n") ? line : "#{line}\n" }.join
    end
    VBOX_COMPONENT.define_singleton_method(:component?) { true }
  end
end
