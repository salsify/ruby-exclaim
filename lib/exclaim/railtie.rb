# frozen_string_literal: true

module Exclaim
  class Railtie < Rails::Railtie
    initializer 'exclaim.config' do
      Exclaim.configure do |config|
        config.logger = Rails.logger
      end
    end
  end
end
