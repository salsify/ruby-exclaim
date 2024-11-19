# frozen_string_literal: true

describe "basic component rendering" do
  let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map) }
  let(:component_implementation) { ->(_config, _env) {} }
  let(:implementation_map) { { 'cmp' => component_implementation } }
  let(:parsed_component) { Exclaim::Component.new(implementation: component_implementation) }

  before do
    component_implementation.define_singleton_method(:component?) { true }
    exclaim_ui.send(:parsed_ui=, parsed_component)
  end

  context "when a component implementation raises an exception" do
    let(:component_implementation) { ->(_config, _env) { raise StandardError.new('anything') } }

    it "raises an Exclaim::Error" do
      expect { exclaim_ui.render }.to raise_error(Exclaim::Error, 'anything')
    end
  end

  it "raises an error if an arbitrary exception occurs internally" do

    # use knowledge of implementation to prompt exception
    allow(exclaim_ui.renderer).to receive(:call).and_raise('Something went wrong')

    expect { exclaim_ui.render }.to raise_error(Exclaim::Error)
    expect { exclaim_ui.render }.to raise_error(Exclaim::InternalError)
  end

  it "raises an error if render called before parsing a UI config" do
    exclaim_ui.send(:parsed_ui=, nil)

    error_message = 'Cannot render without UI configured, must call Exclaim::Ui#parse_ui(ui_config) first'
    expect { exclaim_ui.render }
      .to raise_error(Exclaim::Error, error_message)
  end

  describe "literal component configuration" do
    let(:component_implementation) { ->(config, _env) { config['content'] } }

    it "calls a component implementation and returns the result" do
      expect(exclaim_ui.render).to eq(nil)

      parsed_component.config = { 'content' => 'Hello, world!' }
      expect(exclaim_ui.render).to eq('Hello, world!')

      parsed_component.config = { 'content' => 'How are you?' }
      expect(exclaim_ui.render).to eq('How are you?')

      parsed_component.implementation = ->(config, _env) { config['content'].upcase }
      expect(exclaim_ui.render).to eq('HOW ARE YOU?')
    end
  end

  describe "configuration with helper references" do
    let(:component_implementation) { ->(config, _env) { "Helper result: #{config['content']}" } }

    it "integrates a helper result into component configuration" do
      helper_implementation = ->(config, _env) { config['items'].join(config['separator']) }
      helper = Exclaim::Helper.new(name: 'join', implementation: helper_implementation)
      parsed_component.config = { 'content' => helper }

      helper.config = { 'items' => [1, 2, 3], 'separator' => '+' }
      expect(exclaim_ui.render).to eq('Helper result: 1+2+3')

      helper.config = { 'items' => ['butter', 'sugar'], 'separator' => ' and ' }
      expect(exclaim_ui.render).to eq('Helper result: butter and sugar')
    end
  end

  describe "configuration with bind references" do
    let(:component_implementation) { ->(config, _env) { "Bound value: #{config['content']}" } }

    context "single level bind path" do
      it "evaluates the bound value with the given env" do
        bind = Exclaim::Bind.new(path: 'x')
        parsed_component.config = { 'content' => bind }

        env = { 'x' => 5 }
        expect(exclaim_ui.render(env: env)).to eq('Bound value: 5')

        env = { 'x' => 'five' }
        expect(exclaim_ui.render(env: env)).to eq('Bound value: five')
      end

      it "assumes path represents a string key when indexing a hash field" do
        bind = Exclaim::Bind.new(path: '1')
        parsed_component.config = { 'content' => bind }

        env = { '1' => 5 }
        expect(exclaim_ui.render(env: env)).to eq('Bound value: 5')

        bind = Exclaim::Bind.new(path: '1')
        parsed_component.config = { 'content' => bind }

        env = { 1 => 5 }
        expect(exclaim_ui.render(env: env)).to eq('Bound value: ')
      end
    end

    context "array index as path" do
      it "evaluates the bound value with the given env" do
        bind = Exclaim::Bind.new(path: '2')
        parsed_component.config = { 'content' => bind }

        env = ['zero', 'one', 'two']
        expect(exclaim_ui.render(env: env)).to eq('Bound value: two')
      end

      it "assumes path represents an integer key when indexing an array field" do
        bind = Exclaim::Bind.new(path: 'not_an_integer')
        parsed_component.config = { 'content' => bind }

        env = []
        expect(exclaim_ui.render(env: env)).to eq('Bound value: ')
      end

      it "evaluates to nil when index is out of bounds" do
        bind = Exclaim::Bind.new(path: '0')
        parsed_component.config = { 'content' => bind }

        env = []
        expect(exclaim_ui.render(env: env)).to eq('Bound value: ')
      end
    end

    context "dot-separated bind path" do
      it "evaluates the bound value within the nested env" do
        bind = Exclaim::Bind.new(path: 'x.y.z')
        parsed_component.config = { 'content' => bind }

        env = { 'x' => { 'y' => { 'z' => 5 } } }
        expect(exclaim_ui.render(env: env)).to eq('Bound value: 5')
      end

      it "evaluates a path that blends string keys and array indices" do
        bind = Exclaim::Bind.new(path: 'a_key.1.another_key')
        parsed_component.config = { 'content' => bind }

        env = { 'a_key' => [{ 'another_key' => 'zero' }, { 'another_key' => 'one' }] }
        expect(exclaim_ui.render(env: env)).to eq('Bound value: one')
      end
    end
  end

  describe "configuration with shorthand properties" do
    let(:component_implementation) { ->(config, _env) { config['$text'] || config['content'] } }

    it "a component implementation can support a shorthand property" do
      parsed_component.config = { 'content' => 'longhand' }
      expect(exclaim_ui.render).to eq('longhand')

      parsed_component.config = { '$text' => 'shorthand' }
      expect(exclaim_ui.render).to eq('shorthand')
    end

    it "a helper implementation can support a shorthand property" do
      helper_implementation = ->(config, _env) do
        items = config['$join'] || config['items']

        # also an implementation-defined default for the non-shorthand property
        separator = config['separator'] || ', '

        items.join(separator)
      end
      helper = Exclaim::Helper.new(name: 'join', implementation: helper_implementation)
      parsed_component.config = { 'content' => helper }

      helper.config = { 'items' => [1, 2, 3] }
      expect(exclaim_ui.render).to eq('1, 2, 3')

      helper.config = { '$join' => [1, 2, 3], 'separator' => '; ' }
      expect(exclaim_ui.render).to eq('1; 2; 3')
    end
  end
end
