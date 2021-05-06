# frozen_string_literal: true

describe "rendering HTML configuration values" do
  let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map) }
  let(:component_implementation) { ->(_config, _env) {} }
  let(:implementation_map) { { 'cmp' => component_implementation } }
  let(:parsed_component) { Exclaim::Component.new(implementation: component_implementation) }
  let(:bind) { Exclaim::Bind.new(path: 'env_value') }

  before do
    component_implementation.define_singleton_method(:component?) { true }
    exclaim_ui.send(:parsed_ui=, parsed_component)
  end

  describe "it escapes HTML config values by default" do
    let(:component_implementation) do
      ->(config, _env) { "#{config['config_value']} #{config['bind_value']}" }
    end

    it "replaces <, >, &, \", and ' in string config values" do
      parsed_component.config = {
        'config_value' => '<script>alert("Hello");</script>',
        'bind_value' => bind
      }
      env = { 'env_value' => "<img src='http://test.com/tracking-pixel.png?source=A&type=Z'>" }

      result = exclaim_ui.render(env: env)
      expect(result).to eq('&lt;script&gt;alert(&quot;Hello&quot;);&lt;/script&gt; &lt;img src=&#39;http://test.com/tracking-pixel.png?source=A&amp;type=Z&#39;&gt;')
    end

    it "string config values will be duplicated, not mutated" do
      parsed_component.config = {
        'config_value' => '<script>alert("Hello");</script>',
        'bind_value' => bind
      }
      env = { 'env_value' => "<img src='http://test.com/tracking-pixel.png?source=A&type=Z'>" }

      result = exclaim_ui.render(env: env)

      expect(result).to eq('&lt;script&gt;alert(&quot;Hello&quot;);&lt;/script&gt; &lt;img src=&#39;http://test.com/tracking-pixel.png?source=A&amp;type=Z&#39;&gt;')
      expect(parsed_component.config['config_value']).to eq('<script>alert("Hello");</script>')
      expect(env['env_value']).to eq("<img src='http://test.com/tracking-pixel.png?source=A&type=Z'>")
    end
  end

  describe "it does not escape HTML config values when told not to" do
    let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map, should_escape_html: false) }
    let(:component_implementation) do
      ->(config, _env) { "#{config['config_value']} #{config['bind_value']}" }
    end

    it "does not replace <, >, &, \", and ' in string config values" do
      parsed_component.config = {
        'config_value' => '<script>alert("Hello");</script>',
        'bind_value' => bind
      }
      env = { 'env_value' => "<img src='http://test.com/tracking-pixel.png?source=A&type=Z'>" }

      result = exclaim_ui.render(env: env)
      expect(result).to eq(
        '<script>alert("Hello");</script> <img src=\'http://test.com/tracking-pixel.png?source=A&type=Z\'>'
      )
    end
  end

  context "when rendering helpers" do
    let(:component_implementation) do
      ->(config, _env) { config['config_value'] }
    end
    let(:helper) { Exclaim::Helper.new }
    let(:env) { { 'env_value' => '<script>alert("Hello");</script>' } }

    before do
      helper.config = { 'bind_value' => bind }
      parsed_component.config = {
        'config_value' => helper
      }
    end

    it "helper output will be escaped when provided to component" do
      helper.implementation = ->(config, _env) { "<code>#{config['bind_value']}</code>" }

      result = exclaim_ui.render(env: env)
      expected = '&lt;code&gt;&lt;script&gt;alert(&quot;Hello&quot;);&lt;/script&gt;&lt;/code&gt;'
      expect(result).to eq(expected)
    end

    context "when helper returns a Hash" do
      let(:component_implementation) do
        ->(config, _env) { config['config_value']['hash_key'] }
      end

      it "string values inside the Hash will be escaped when provided to component" do
        helper.implementation = ->(config, _env) do
          {
            'hash_key' => config['bind_value']
          }
        end

        result = exclaim_ui.render(env: env)
        expected = '&lt;script&gt;alert(&quot;Hello&quot;);&lt;/script&gt;'
        expect(result).to eq(expected)
      end
    end

    context "when helper returns an Array" do
      let(:component_implementation) do
        ->(config, _env) { config['config_value'][0] }
      end

      it "string values inside the Array will be escaped when provided to component" do
        helper.implementation = ->(config, _env) do
          [config['bind_value']]
        end

        result = exclaim_ui.render(env: env)
        expected = '&lt;script&gt;alert(&quot;Hello&quot;);&lt;/script&gt;'
        expect(result).to eq(expected)
      end
    end

    context "when helper returns other JSON-compatible values" do
      let(:component_implementation) do
        ->(config, _env) { config['config_value'] }
      end

      it "provides them to component implementation without escaping them" do
        helper.implementation = ->(config, _env) do
          int, float, yes, null, no = config['bind_value']
          raise 'int value not preserved' unless int == -1
          raise 'float value not preserved' unless float.is_a?(Float)
          raise 'true value not preserved' unless yes == true
          raise 'false value not preserved' unless no == false
          raise 'nil value not preserved' unless null.nil?

          'OK'
        end

        result = exclaim_ui.render(env: { 'env_value' => [-1, 2.0, true, nil, false] })
        expect(result).to eq('OK')
      end
    end

    context "when helper returns a non JSON-compatible custom value" do
      let(:component_implementation) do
        ->(config, _env) { config['config_value'].safe_html }
      end

      it "can smuggle an unescaped HTML value to the component config" do
        safe_html_wrapper = Struct.new(:safe_html)

        helper.implementation = ->(config, _env) do
          safe_html_wrapper.new(config['bind_value'])
        end

        result = exclaim_ui.render(env: { 'env_value' => '<p>Guaranteed safe!</p>' })
        expect(result).to eq('<p>Guaranteed safe!</p>')
      end
    end
  end

  describe "component implementations can build HTML themselves" do
    let(:component_implementation) do
      ->(config, _env) do
        "<script>alert(\"#{config['config_value']}\");</script> <img src='#{config['bind_value']}'>"
      end
    end

    it "does not escape component output" do
      parsed_component.config = {
        'config_value' => 'Hello',
        'bind_value' => bind
      }
      env = { 'env_value' => 'http://test.com/tracking-pixel.png' }

      result = exclaim_ui.render(env: env)
      expect(result).to eq("<script>alert(\"Hello\");</script> <img src='http://test.com/tracking-pixel.png'>")
    end
  end

  describe "component implementations can unescape HTML if they trust it" do
    let(:component_implementation) do
      ->(config, _env) do
        user_script = CGI.unescape_html(config['config_value'])
        user_image = CGI.unescape_html(config['bind_value'])
        "#{user_script} #{user_image}"
      end
    end

    it "restores user-specified HTML" do
      parsed_component.config = {
        'config_value' => '<script>alert("Hello");</script>',
        'bind_value' => bind
      }
      env = { 'env_value' => "<img src='http://test.com/tracking-pixel.png?source=A&type=Z'>" }

      result = exclaim_ui.render(env: env)
      expected = '<script>alert("Hello");</script> ' \
                 "<img src='http://test.com/tracking-pixel.png?source=A&type=Z'>"
      expect(result).to eq(expected)
    end
  end

  describe "component implementations can unescape HTML and selectively re-escape it" do
    let(:component_implementation) do
      ->(config, _env) do
        unsafe_elements = ['SCRIPT', 'IFRAME']
        user_script = CGI.unescape_html(config['config_value'])
        user_iframe = CGI.unescape_html(config['bind_value'])
        "#{CGI.escape_element(user_script, *unsafe_elements)} #{CGI.escape_element(user_iframe, *unsafe_elements)}"
      end
    end

    it "partially restores user-specified HTML" do
      parsed_component.config = {
        'config_value' => '<h1><script>alert("Hello");</script></h1>',
        'bind_value' => bind
      }
      env = { 'env_value' => "<div><iframe src='http://test.com/tracking-pixel.png?source=A&type=Z'></iframe></div>" }

      result = exclaim_ui.render(env: env)
      expected = '<h1>&lt;script&gt;alert("Hello");&lt;/script&gt;</h1> ' \
                 '<div>' \
                '&lt;iframe src=&#39;http://test.com/tracking-pixel.png?source=A&amp;type=Z&#39;&gt;&lt;/iframe&gt;' \
                '</div>'
      expect(result).to eq(expected)
    end
  end

  describe "components can work with helpers to display escaped HTML within unescaped HTML" do
    let(:component_implementation) do
      ->(config, _env) { "<code>#{config['config_value']}</code>" }
    end

    it "does not escape input not output, but output will be escaped when provided to component" do
      helper = Exclaim::Helper.new(implementation: ->(config, _env) { "<script>#{config['bind_value']}</script>" })
      helper.config = { 'bind_value' => bind }
      parsed_component.config = {
        'config_value' => helper
      }
      env = { 'env_value' => 'alert("Hello");' }

      result = exclaim_ui.render(env: env)
      expected = '<code>&lt;script&gt;alert(&quot;Hello&quot;);&lt;/script&gt;</code>'
      expect(result).to eq(expected)
    end
  end
end
