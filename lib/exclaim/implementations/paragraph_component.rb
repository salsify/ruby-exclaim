# frozen_string_literal: true

module Exclaim
  module Implementations
    PARAGRAPH_COMPONENT = ->(config, env, &render_child) do
      sentences = config['sentences'] || config['$paragraph']
      rendered_sentences = sentences.map do |sentence|
        result = render_child.call(sentence, env)
        result.end_with?('.') ? result : "#{result}."
      end
      "<p>#{rendered_sentences.join(' ')}</p>"
    end
    PARAGRAPH_COMPONENT.define_singleton_method(:component?) { true }
  end
end
