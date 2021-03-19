# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'exclaim'

RSpec.configure do |c|
  c.example_status_persistence_file_path = 'examples.txt'
end
