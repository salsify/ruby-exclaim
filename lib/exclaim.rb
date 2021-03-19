# frozen_string_literal: true

require 'logger'
require 'exclaim/version'
require 'exclaim/utilities'

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
