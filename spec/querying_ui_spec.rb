# frozen_string_literal: true

describe "querying a parsed Exclaim::Ui instance" do
  let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map) }
  let(:implementation_map) { Exclaim::Implementations.example_implementation_map }

  describe "#unique_bind_paths" do
    it "raises an error if the UI configuration has not been parsed yet" do
      error_message = 'Cannot compute unique_bind_paths without UI configured, ' \
                      'must call Exclaim::Ui#parse_ui(ui_config) first'
      expect { exclaim_ui.unique_bind_paths }.to raise_error(Exclaim::Error, error_message)
    end

    it "returns the deduplicated bind path strings from the UI configuration" do
      parsed_ui = Exclaim::Component.new(name: 'top_component')
      bind_1 = Exclaim::Bind.new(path: 'path.1')
      bind_2 = Exclaim::Bind.new(path: 'path.2')
      helper = Exclaim::Helper.new
      helper.config = { '$join' => bind_2 }
      bind_3 = Exclaim::Bind.new(path: 'path.3')
      bind_4 = Exclaim::Bind.new(path: 'path.4')
      bind_5 = Exclaim::Bind.new(path: 'path.5')
      child_component = Exclaim::Component.new(name: 'child_component')
      child_component.config = { 'label' => bind_5 }

      parsed_ui.config = {
        'field' => bind_1,
        'another' => helper,
        'items' => [bind_3],
        'unrelated' => 'string',
        'nested' => { 'array of hashes' => [{ 'is ok' => bind_4 }] },
        'duplicate' => bind_2,
        'children' => [child_component]
      }

      exclaim_ui.send(:parsed_ui=, parsed_ui)

      expect(exclaim_ui.unique_bind_paths).to eq(['path.1', 'path.2', 'path.3', 'path.4', 'path.5'])
    end
  end

  describe "#each_element" do
    let(:implementation_map) do
      # basic component element
      text = ->(config, _env) { config['content'] }
      text.define_singleton_method(:component?) { true }

      # basic helper element
      join = ->(config, _env) { config['items'].join(', ') }
      join.define_singleton_method(:helper?) { true }

      # element with config including Array of nested elements
      vbox = ->(config, env) { config['children'].map { |item| item.call(config, env) } }
      vbox.define_singleton_method(:component?) { true }

      # element with config including Hash of nested elements
      error_message = ->(config, _env) { config.dig('result', 'error', 'message') }
      error_message.define_singleton_method(:helper?) { true }
      {
        'vbox' => vbox,
        'text' => text,
        'join' => join,
        'error_message' => error_message
      }
    end
    let(:bind_config) { { '$bind' => 'items_variable' } }
    let(:join_helper_config) { { '$helper' => 'join', 'items' => bind_config } }
    let(:text1_config) do
      {
        '$component' => 'text',
        'content' => join_helper_config
      }
    end
    let(:text2_config) do
      {
        '$component' => 'text',
        'content' => 'Something went wrong'
      }
    end
    let(:error_message_config) do
      {
        '$helper' => 'error_message',
        'result' => { 'error' => { 'message' => text2_config } }
      }
    end
    let(:ui_config) do
      {
        '$component' => 'vbox',
        'children' => [
          text1_config,
          error_message_config
        ]
      }
    end

    it "raises an error if the UI configuration has not been parsed yet" do
      error_message = 'Cannot compute each_element without UI configured, ' \
                      'must call Exclaim::Ui#parse_ui(ui_config) first'
      expect { exclaim_ui.each_element }.to raise_error(Exclaim::Error, error_message)
    end

    it "yields the raw JSON configuration for each Exclaim element detected in the declared UI" do
      exclaim_ui.parse_ui!(ui_config)

      expected = [ui_config, text1_config, join_helper_config, bind_config, error_message_config, text2_config]
      expect { |b| exclaim_ui.each_element(&b) }.to yield_successive_args(*expected)
    end

    it "returns an Enumerator if no block given" do
      exclaim_ui.parse_ui!(ui_config)

      return_value = exclaim_ui.each_element
      expect(return_value).to be_an(Enumerator)
      expected = [ui_config, text1_config, join_helper_config, bind_config, error_message_config, text2_config]
      expect(return_value.to_a).to eq(expected)
    end

    describe "filtering yielded elements" do
      it "accepts an element name and only yields those elements from the UI configuration" do
        exclaim_ui.parse_ui!(ui_config)

        expected = [text1_config, text2_config]
        expect { |b| exclaim_ui.each_element('text', &b) }.to yield_successive_args(*expected)
      end

      it "allows element name to have a leading '$', and yields those elements from the UI configuration" do
        exclaim_ui.parse_ui!(ui_config)

        expected = [text1_config, text2_config]
        expect { |b| exclaim_ui.each_element('$text', &b) }.to yield_successive_args(*expected)
      end

      it "accepts an array of element names and only yields those elements from the UI configuration" do
        exclaim_ui.parse_ui!(ui_config)

        expected = [text1_config, bind_config, text2_config]
        expect { |b| exclaim_ui.each_element(['text', '$bind'], &b) }.to yield_successive_args(*expected)
      end

      it "raises an error if given an element_names value that is not a String or Array" do
        exclaim_ui.parse_ui!(ui_config)

        error_message = 'Exclaim::Ui#each_element: element_names argument must be a String or Array, given NilClass'
        expect { exclaim_ui.each_element(nil) }.to raise_error(Exclaim::Error, error_message)
      end
    end
  end
end
