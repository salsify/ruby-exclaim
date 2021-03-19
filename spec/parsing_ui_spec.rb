# frozen_string_literal: true

describe "parsing UI configuration" do
  let(:text_component) do
    implementation = ->(config, _env) do
      content = config['content'] || config['$text']
      content
    end
    implementation.define_singleton_method(:component?) { true }
    implementation
  end
  let(:paragraph_component) do
    implementation = ->(config, _env) do
      content = config['sentence'] || config['$paragraph']
      "<p>#{content}</p>"
    end
    implementation.define_singleton_method(:component?) { true }
    implementation
  end
  let(:join_helper) do
    implementation = ->(config, _env) { (config['items'] || config['$join']).join(config['separator']) }
    implementation.define_singleton_method(:helper?) { true }
    implementation
  end
  let(:capitalize_helper) do
    implementation = ->(config, _env) { (config['content'] || config['$capitalize']).capitalize }
    implementation.define_singleton_method(:helper?) { true }
    implementation
  end
  let(:implementation_map) do
    {
      'text' => text_component,
      'paragraph' => paragraph_component,
      'capitalize' => capitalize_helper,
      'join' => join_helper
    }
  end
  let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map) }
  let(:ui_config) { {} }

  it "raises an error if UI configuration is not a Hash" do
    expect { exclaim_ui.parse_ui!(nil) }
      .to raise_error(Exclaim::Error, 'ui_config must be a Hash, given: NilClass')
  end

  it "raises an error if the top-level Hash is not a component" do
    ui_config = {
      'random' => 'hash',
      'not a' => 'component'
    }

    error_message = 'ui_config must declare a component at the top-level that is present in implementation_map'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end

  it "raises an error if multiple component references present in one level of config" do
    ui_config = {
      '$component' => 'text',
      'content' => 'hello',
      '$text' => 'hello'
    }

    error_message = 'Multiple Exclaim elements defined at one configuration level: ["text", "text"]. Only one allowed.'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end

  it "raises an error if multiple helper references present in one level of config" do
    ui_config = {
      '$join' => ['a', 'b'],
      'content' => 'hello',
      '$helper' => 'capitalize'
    }

    error_message = 'Multiple Exclaim elements defined at one configuration level: ["join", "capitalize"]. ' \
                    'Only one allowed.'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end

  it "raises an error if both a component and helper references present in one level of config" do
    ui_config = {
      '$component' => 'text',
      'content' => 'hello',
      '$helper' => 'capitalize'
    }

    error_message = 'Multiple Exclaim elements defined at one configuration level: ["text", "capitalize"]. ' \
                    'Only one allowed.'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end

  it "raises an error if explicit component name starts with $" do
    ui_config = {
      '$component' => '$text',
      'content' => 'hello'
    }

    error_message = 'Invalid: "$component": "$text", when declaring explicit "$component" ' \
                    'do not prefix the name with "$"'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end

  it "raises an error if explicit helper name starts with $" do
    ui_config = {
      '$helper' => '$capitalize',
      'content' => 'hello'
    }

    error_message = 'Invalid: "$helper": "$capitalize", '\
                    'when declaring explicit "$helper" do not prefix the name with "$"'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end

  it "raises an error if an arbitrary exception occurs internally" do
    ui_config = {
      '$component' => 'text',
      'content' => 'hello'
    }
    # use knowledge of implementation to prompt exception
    allow(Exclaim::UiConfiguration).to receive(:parse!).and_raise('Something went wrong')

    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error)
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::InternalError)
  end

  it "transforms component declarations into Exclaim::Component elements" do
    ui_config = {
      '$component' => 'text',
      'content' => 'hello'
    }

    exclaim_ui.parse_ui!(ui_config)

    expect(exclaim_ui.parsed_ui).to be_a(Exclaim::Component)
    expect(exclaim_ui.parsed_ui.name).to eq('text')
  end

  it "normalizes the parsed Component name with shorthand declarations" do
    ui_config = {
      '$text' => 'hello'
    }

    exclaim_ui.parse_ui!(ui_config)

    expect(exclaim_ui.parsed_ui).to be_a(Exclaim::Component)
    expect(exclaim_ui.parsed_ui.name).to eq('text')
  end

  context "when a configuration key looks like an Exclaim element but is unrecognized in implementation_map" do
    it "raises an error if it implies no component recognized at the top-level of the ui_config" do
      ui_config = {
        '$something' => 'hello'
      }
      allow(Exclaim.logger).to receive(:warn)

      warning_message = 'ui_config includes key "$something" which has no matching implementation'
      error_message = 'ui_config must declare a component at the top-level that is present in implementation_map'
      expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
      expect(Exclaim.logger).to have_received(:warn).with(warning_message)
    end

    it "raises an error if an explicit $component key has no recognized implementation" do
      ui_config = {
        '$component' => 'text',
        'content' => { '$capitalize' => { '$component' => 'first_name' } }
      }

      error_message = 'ui_config declares "$component": "first_name" which has no matching implementation'
      expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
    end

    it "raises an error if an explicit $helper key has no recognized implementation" do
      ui_config = {
        '$component' => 'text',
        'content' => { '$helper' => 'upcase', 'value' => 'abc' }
      }

      error_message = 'ui_config declares "$helper": "upcase" which has no matching implementation'
      expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
    end

    it "otherwise it logs a warning, because key starting with '$' might just be non-Exclaim item" do
      allow(Exclaim.logger).to receive(:warn)
      ui_config = {
        '$component' => 'text',
        '$something' => 'else',
        'content' => 'hello'
      }
      exclaim_ui.parse_ui!(ui_config)
      warning_message = 'ui_config includes key "$something" which has no matching implementation'
      expect(Exclaim.logger).to have_received(:warn).with(warning_message)

      ui_config = {
        '$text' => { '$ai_helper' => 'original thoughts' }
      }

      exclaim_ui.parse_ui!(ui_config)
      warning_message = 'ui_config includes key "$ai_helper" which has no matching implementation'
      expect(Exclaim.logger).to have_received(:warn).with(warning_message)
    end
  end

  it "attaches the declared config to the parsed Component" do
    ui_config = {
      '$component' => 'text',
      'content' => 'hello'
    }

    exclaim_ui.parse_ui!(ui_config)

    expect(exclaim_ui.parsed_ui).to be_a(Exclaim::Component)
    expect(exclaim_ui.parsed_ui.config).to eq({ '$component' => 'text',
                                                'content' => 'hello' })
  end

  it "attaches the matching implementation to the parsed Component" do
    ui_config = {
      '$text' => 'hello'
    }

    exclaim_ui.parse_ui!(ui_config)

    expect(exclaim_ui.parsed_ui).to be_a(Exclaim::Component)
    expect(exclaim_ui.parsed_ui.implementation).to eq(implementation_map['text'])
  end

  describe "UI configuration with nested helpers and components" do
    it "transforms the nested declarations into Component and Helper elements" do
      ui_config = {
        '$component' => 'text',
        'content' => {
          '$join' => [
            '<p>First paragraph</p>',
            { '$component' => 'paragraph', 'sentence' => 'Second sentence.' }
          ]
        }
      }

      exclaim_ui.parse_ui!(ui_config)

      expect(exclaim_ui.parsed_ui).to be_a(Exclaim::Component)

      top_level_component = exclaim_ui.parsed_ui
      expect(top_level_component.config['$component']).to eq('text')
      helper = top_level_component.config['content']
      expect(helper.name).to eq('join')
      expect(helper.config['$join']).to be_a(Array)
      join_items = helper.config['$join']
      expect(join_items[0]).to eq('<p>First paragraph</p>')
      child_component = join_items[1]
      expect(child_component).to be_a(Exclaim::Component)
      expect(child_component.name).to eq('paragraph')
      expect(child_component.config).to eq({ '$component' => 'paragraph', 'sentence' => 'Second sentence.' })
    end

    it "traverses through multiple levels of non-Exclaim collections configuration" do
      # A Component or Helper could potentially use nested collections as configuration values,
      # meaning the UI config might not have an Exclaim element at every level.
      # Other than a requiring top-level Component, it is OK for a config level to only have literal values.

      # Assume the "paragraph" component has an implementation like this:
      #   -> (config, env) { config['files'][0]['lines'] }
      # Therefore the UI might declare a config value like this:
      ui_config = {
        '$component' => 'paragraph',
        'files' => [{ 'lines' => { '$bind' => 'data' } }]
      }

      exclaim_ui.parse_ui!(ui_config)

      top_level_component = exclaim_ui.parsed_ui
      expect(top_level_component.config.dig('files', 0, 'lines')).to be_a(Exclaim::Bind)
    end
  end

  it "transforms $bind references in Bind elements" do
    ui_config = {
      '$component' => 'text',
      'content' => {
        '$join' => [
          { '$component' => 'paragraph', 'sentence' => { '$bind' => 'a.b' } },
          { '$component' => 'paragraph', 'sentence' => { '$bind' => 'c.d' } }
        ]
      }
    }

    exclaim_ui.parse_ui!(ui_config)

    top_level_component = exclaim_ui.parsed_ui
    join_items = top_level_component.config['content'].config['$join']
    bind_0 = join_items[0].config['sentence']
    expect(bind_0).to be_a(Exclaim::Bind)
    expect(bind_0.path).to eq('a.b')
    bind_1 = join_items[1].config['sentence']
    expect(bind_1).to be_a(Exclaim::Bind)
    expect(bind_1.path).to eq('c.d')
  end

  it "raises an error if $bind path is not a String" do
    ui_config = {
      '$component' => 'text',
      'content' => { '$bind' => nil }
    }

    error_message = '$bind path must be a String, found NilClass'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)

    # even a simple array index path should be specified as a string
    ui_config['content']['$bind'] = 0
    error_message = '$bind path must be a String, found Integer'
    expect { exclaim_ui.parse_ui!(ui_config) }.to raise_error(Exclaim::Error, error_message)
  end
end
