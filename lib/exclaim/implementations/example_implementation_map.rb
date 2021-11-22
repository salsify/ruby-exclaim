# frozen_string_literal: true

require_relative 'each_component'
require_relative 'image_component'
require_relative 'if_helper'
require_relative 'join_helper'
require_relative 'let_component'
require_relative 'paragraph_component'
require_relative 'text_component'
require_relative 'vbox_component'

module Exclaim
  module Implementations
    extend self

    def example_implementation_map
      @example_implementation_map ||= {
          'each' => EACH_COMPONENT,
          'image' => IMAGE_COMPONENT,
          'if' => IF_HELPER,
          'join' => JOIN_HELPER,
          'let' => LET_COMPONENT,
          'paragraph' => PARAGRAPH_COMPONENT,
          'text' => TEXT_COMPONENT,
          'vbox' => VBOX_COMPONENT
        }

    end
  end
end
