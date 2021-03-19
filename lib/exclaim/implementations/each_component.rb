# frozen_string_literal: true

module Exclaim
  module Implementations
    class Each
      def component?
        true
      end

      def call(config, env)
        items = (config['items'] || config['$each']).to_a
        bind_reference = config['yield']

        # This implementation mutates the env Hash before passing it to each child element,
        # and then restores the env to its original state at the end.
        original_env_includes_bind_reference = env.key?(bind_reference)
        original_bind_value = env[bind_reference] if original_env_includes_bind_reference
        resolved_items = items.map do |item|
          env[bind_reference] = item
          yield config['do'], env # yields to render_child block
        end

        resolved_items.map { |line| line.end_with?("\n") ? line : "#{line}\n" }.join
      ensure
        env.delete(bind_reference)
        env[bind_reference] = original_bind_value if original_env_includes_bind_reference
      end
    end

    EACH_COMPONENT = Each.new
  end
end
