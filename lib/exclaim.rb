# frozen_string_literal: true

require 'logger'
require 'exclaim/version'
require 'exclaim/errors'
require 'exclaim/utilities'
require 'exclaim/implementation_map'
require 'exclaim/implementations/example_implementation_map'
require 'exclaim/implementable'
require 'exclaim/component'
require 'exclaim/helper'
require 'exclaim/bind'
require 'exclaim/ui_configuration'
require 'exclaim/renderer'
require 'exclaim/ui'

module Exclaim
  extend Utilities
  extend self

  class << self
    attr_accessor :logger

    def configure
      yield self
    end
  end

  # defaults
  self.logger = Logger.new($stdout)
end
