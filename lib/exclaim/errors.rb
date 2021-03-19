# frozen_string_literal: true

module Exclaim
  # allow callers to rescue Exclaim::Error
  module Error
  end

  module InternalError
    include Error
  end

  class ImplementationMapError < RuntimeError
    include Error
  end

  class UiConfigurationError < RuntimeError
    include Error
  end

  class RenderingError < RuntimeError
    include Error
  end
end
