# frozen_string_literal: true

describe "validating implementation map" do
  let(:map_type_error) { /implementation_map must be a Hash, given:/ }
  let(:key_type_error) { /implementation name must be a String, found:/ }
  let(:key_empty_error) { /implementation name cannot be the empty String/ }
  let(:key_prefix_error) { /implementation key '\$cmp' must not start with the \$ symbol, use the un-prefixed name/ }
  let(:interface_error) { /implementation for 'cmp' does not respond to call/ }
  let(:signature_error) do
    message = "implementation for 'cmp' must accept two positional parameters for config and env, " \
            'and optionally a render_child block. Actual parameters: \[.*\]'
    /#{message}/
  end
  let(:component_helper_presence_error) do
    /implementation for 'cmp' must provide a component\? or helper\? predicate method/
  end
  let(:component_helper_complement_error) do
    /implementation for 'cmp' must provide opposite truth values for component\? and helper\? methods/
  end

  def define_all_component_methods(implementation_map, value = true)
    implementation_map.each_value { |implementation| define_component_method(implementation, value) }
  end

  def define_component_method(implementation, value = true)
    implementation.define_singleton_method(:component?) { value }
  end

  it "defaults the implementation_map to example implementation map" do
    expect(Exclaim::Ui.new.implementation_map).to eq(Exclaim::Implementations.example_implementation_map)
  end

  it "raises an error if an arbitrary exception occurs internally" do
    # use knowledge of implementation to prompt exception
    allow(Exclaim::ImplementationMap).to receive(:parse!).and_raise('Something went wrong')

    expect { Exclaim::Ui.new.implementation_map }.to raise_error(Exclaim::Error)
    expect { Exclaim::Ui.new.implementation_map }.to raise_error(Exclaim::InternalError)
  end

  it "raises an error if given a non-Hash implementation_map" do
    expect { Exclaim::Ui.new(implementation_map: nil) }.to raise_error(Exclaim::Error, map_type_error)
  end

  describe "implementation map key names" do
    it "raises an error if an implementation_map key starts with $" do
      expect { Exclaim::Ui.new(implementation_map: { '$cmp' => ->(_c, _e) { 'implementation ' } }) }
        .to raise_error(Exclaim::Error, key_prefix_error)
    end

    it "raises an error if an implementation_map key is not a String" do
      expect { Exclaim::Ui.new(implementation_map: { nil => ->(_c, _e) { 'implementation ' } }) }
        .to raise_error(Exclaim::Error, key_type_error)
    end

    it "raises an error if an implementation_map key is the empty String" do
      expect { Exclaim::Ui.new(implementation_map: { '' => ->(_c, _e) { 'implementation ' } }) }
        .to raise_error(Exclaim::Error, key_empty_error)
    end
  end

  describe "implementation call interface" do
    it "raises an error if any implementation_map value does not provide a call interface" do
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => nil }) }.to raise_error(Exclaim::Error, interface_error)
    end

    it "raises an error if an implementation does not have two required parameters for config and env" do
      implementation_map_0 = { 'cmp' => -> { 'hello' } }
      define_all_component_methods(implementation_map_0)
      expect { Exclaim::Ui.new(implementation_map: implementation_map_0) }
        .to raise_error(Exclaim::Error, signature_error)

      implementation_map_1 = { 'cmp' => ->(_config) { 'hello' } }
      define_all_component_methods(implementation_map_1)
      expect { Exclaim::Ui.new(implementation_map: implementation_map_1) }
        .to raise_error(Exclaim::Error, signature_error)

      implementation_map_2kw = { 'cmp' => ->(_config: {}, _env: {}) { 'hello' } }
      define_all_component_methods(implementation_map_2kw)
      expect { Exclaim::Ui.new(implementation_map: implementation_map_2kw) }
        .to raise_error(Exclaim::Error, signature_error)

      implementation_map_2 = { 'cmp' => ->(_config, _env) { 'hello' } }
      define_all_component_methods(implementation_map_2)
      expect { Exclaim::Ui.new(implementation_map: implementation_map_2) }.not_to raise_error
    end

    it "raises an error if an implementation has config and env parameters that are not positional" do
      implementation_map_kw1 = { 'cmp' => ->(_config, _env: {}) { 'hello' } }
      expect { Exclaim::Ui.new(implementation_map: implementation_map_kw1) }
        .to raise_error(Exclaim::Error, signature_error)

      implementation_map_kw2 = { 'cmp' => ->(_config: {}, _env: {}) { 'hello' } }
      expect { Exclaim::Ui.new(implementation_map: implementation_map_kw2) }
        .to raise_error(Exclaim::Error, signature_error)
    end

    it "implementation may accept a block argument" do
      implementation = ->(config, env, &render_child) { render_child.call(config['child_component'], env) }
      define_component_method(implementation)
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }.not_to raise_error
    end

    it "implementation may be either an object with a call method or other callable" do
      klass = Class.new do
        def call(_config, _env, &_render_child)
          'object instance'
        end

        def helper?
          true
        end
      end
      object_implementation = klass.new
      proc_implementation = Proc.new { |_config, _env, &_render_child| 'proc' }
      define_component_method(proc_implementation, false)
      def m(_config, _env, &_render_child)
        'method'
      end
      method_implementation = method(:m)
      define_component_method(method_implementation, true)

      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => object_implementation }) }.not_to raise_error
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => proc_implementation }) }.not_to raise_error
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => method_implementation }) }.not_to raise_error
    end
  end

  describe "implementation component? and helper? interface" do
    let(:implementation) do
      ->(_config, _env) { 'implementation' }
    end

    it "raises an error if implementation does not respond to component? or helper? method" do
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }
        .to raise_error(Exclaim::Error, component_helper_presence_error)
    end

    it "raises an error if component? and helper? methods both return true" do
      implementation.define_singleton_method(:component?) { true }
      implementation.define_singleton_method(:helper?) { true }
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }
        .to raise_error(Exclaim::Error, component_helper_complement_error)
    end

    it "raises an error if component? and helper? methods both return false" do
      implementation.define_singleton_method(:component?) { false }
      implementation.define_singleton_method(:helper?) { false }
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }
        .to raise_error(Exclaim::Error, component_helper_complement_error)
    end

    it "raises an error if component? and helper? methods both return truthy values" do
      implementation.define_singleton_method(:component?) { 'my name is component' }
      implementation.define_singleton_method(:helper?) { 'my name is helper' }
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }
        .to raise_error(Exclaim::Error, component_helper_complement_error)
    end

    it "raises an error if component? and helper? methods both return falsy values" do
      implementation.define_singleton_method(:component?) { nil }
      implementation.define_singleton_method(:helper?) { false }
      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }
        .to raise_error(Exclaim::Error, component_helper_complement_error)
    end

    it "allows implementation to only define the component? predicate" do
      implementation.define_singleton_method(:component?) { true }

      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }.not_to raise_error
    end

    it "allows implementation to only define the helper? predicate" do
      implementation.define_singleton_method(:helper?) { false }

      expect { Exclaim::Ui.new(implementation_map: { 'cmp' => implementation }) }.not_to raise_error
    end
  end
end
