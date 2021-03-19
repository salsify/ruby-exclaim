# frozen_string_literal: true

describe "rendering nested configuration" do
  let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map) }
  let(:top_level_component) { Exclaim::Component.new(implementation: top_level_component_implementation) }
  let(:top_level_component_implementation) do
    ->(config, _env) do
      "Top-level value: #{config['top_level_scalar']}" \
        " / Outer hash value: #{config['top_level_hash']['outer_key']}" \
        " / Nested array value: #{config['top_level_hash']['array_key'][0]}" \
        " / Inner hash value: #{config['top_level_hash']['array_key'][1]['inner_key']}"
    end
  end
  let(:implementation_map) { { 'cmp' => top_level_component_implementation } }

  before do
    top_level_component_implementation.define_singleton_method(:component?) { true }
    exclaim_ui.send(:parsed_ui=, top_level_component)
  end

  it "handles nested literals" do
    top_level_component.config = {
      'top_level_scalar' => '1',
      'top_level_hash' => {
        'outer_key' => '2',
        'array_key' => [
          '3',
          { 'inner_key' => '4' }
        ]
      }
    }

    rendered = exclaim_ui.render
    expect(rendered).to eq('Top-level value: 1 / Outer hash value: 2 / Nested array value: 3 / Inner hash value: 4')
  end

  it "handles nested helpers and binds" do
    helper_2 = Exclaim::Helper.new(implementation: ->(config, _env) { 1 + config['addend'] })
    helper_2.config = { 'addend' => 1 }

    bind_3 = Exclaim::Bind.new(path: 'array.3')

    helper_4 = Exclaim::Helper.new(implementation: ->(config, _env) { config['multiplicand'] * 4 })
    bind_4 = Exclaim::Bind.new(path: 'value.to.quadruple')
    helper_4.config = { 'multiplicand' => bind_4 }

    env = {
      'array' => [0, 1, 2, 3],
      'value' => { 'to' => { 'quadruple' => 1 } }
    }

    top_level_component.config = {
      'top_level_scalar' => '1',
      'top_level_hash' => {
        'outer_key' => helper_2,
        'array_key' => [
          bind_3,
          { 'inner_key' => helper_4 }
        ]
      }
    }

    rendered = exclaim_ui.render(env: env)
    expect(rendered).to eq('Top-level value: 1 / Outer hash value: 2 / Nested array value: 3 / Inner hash value: 4')
  end

  describe "when a component's configuration includes child components" do
    let(:list_component_implementation) do
      ->(config, env, &render_child) do
        list_items = config['list_items'].map do |li|
          item = render_child.call(li, env)
          "  <li>#{item}</li>"
        end

        <<~LIST
          <ul>
          #{list_items.join("\n")}
          </ul>
        LIST
      end
    end
    let(:top_level_component_implementation) { list_component_implementation }
    let(:child_component_implementation) do
      ->(_config, env) { "Item #{env['n']}" }
    end
    let(:env) { { 'n' => 1 } }
    let(:child_component) { Exclaim::Component.new(implementation: child_component_implementation) }

    it "provides the rendered children to the parent implementation" do
      top_level_component.config = {
        'list_items' => [
          child_component
        ]
      }

      expected = <<~EXPECTED
        <ul>
          <li>Item 1</li>
        </ul>
      EXPECTED
      expect(exclaim_ui.render(env: env)).to eq(expected)
    end

    it "handles when child config is a mix of components and other elements" do
      child_literal = 'Item 2'
      child_helper = Exclaim::Helper.new(implementation: ->(config, _env) do
        "Item #{config['helper_n']}"
      end)
      child_helper.config = { 'helper_n' => 3 }
      top_level_component.config = {
        'list_items' => [
          child_component,
          child_literal,
          child_helper
        ]
      }

      expected = <<~EXPECTED
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
          <li>Item 3</li>
        </ul>
      EXPECTED
      expect(exclaim_ui.render(env: env)).to eq(expected)
    end

    context "when children config includes a helper, and then the helper takes components as its own config" do
      let(:child_helper) do
        Exclaim::Helper.new(name: 'if',
                            implementation: ->(config, _env) do
                              if config['if_condition']
                                config['then_component']
                              else
                                config['else_component']
                              end
                            end)
      end
      let(:greeting_implementation) { ->(config, _env) { "#{config['greeting']}, #{config['name']}" } }
      let(:parsed_then_component) { Exclaim::Component.new(name: 'greeting', implementation: greeting_implementation) }
      let(:parsed_else_component) { Exclaim::Component.new(name: 'greeting', implementation: greeting_implementation) }

      it "correctly renders the child components and provides them to the parent" do
        greeting_bind = Exclaim::Bind.new(path: 'greeting_text')
        parsed_then_component.config = {
          'greeting' => greeting_bind,
          'name' => 'Sun'
        }
        parsed_else_component.config = {
          'greeting' => greeting_bind,
          'name' => 'Moon'
        }

        condition_bind = Exclaim::Bind.new(path: 'before_noon')
        child_helper.config = {
          'if_condition' => condition_bind,
          'then_component' => parsed_then_component,
          'else_component' => parsed_else_component
        }

        top_level_component.config = {
          'list_items' => [
            child_helper
          ]
        }

        env = { 'before_noon' => true, 'greeting_text' => 'Good morning' }
        expected = <<~EXPECTED
          <ul>
            <li>Good morning, Sun</li>
          </ul>
        EXPECTED
        expect(exclaim_ui.render(env: env)).to eq(expected)

        env = { 'before_noon' => false, 'greeting_text' => 'Good evening' }
        expected = <<~EXPECTED
          <ul>
            <li>Good evening, Moon</li>
          </ul>
        EXPECTED
        expect(exclaim_ui.render(env: env)).to eq(expected)
      end
    end

    context "when component implementation alters the env for child components" do
      let(:list_component_implementation) do
        ->(config, env, &render_child) do
          list_items = config['list_items'].map.with_index(1) do |li, n|
            env['n'] = n
            item = render_child.call(li, env)
            "  <li>#{item}</li>"
          end

          <<~LIST
            <ul>
            #{list_items.join("\n")}
            </ul>
          LIST
        end
      end
      let(:top_level_component_implementation) { list_component_implementation }

      it "child components are rendered with the modified env" do
        top_level_component.config = {
          'list_items' => [
            child_component,
            child_component,
            child_component
          ]
        }

        expected = <<~EXPECTED
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
            <li>Item 3</li>
          </ul>
        EXPECTED
        expect(exclaim_ui.render(env: env)).to eq(expected)
      end

      context "with multiple levels of nesting" do
        let(:list_component_implementation) do
          ->(config, env, &render_child) do
            list_items = config['list_items'].map.with_index(config['start_index']) do |li, n|
              env['n'] = n
              item = render_child.call(li, env, &render_child)
              "  <li>#{item}</li>"
            end

            <<~LIST
              <ul>
              #{list_items.join("\n")}
              </ul>
            LIST
          end
        end
        let(:top_level_component_implementation) { list_component_implementation }
        let(:intermediate_parent_component) { Exclaim::Component.new(implementation: list_component_implementation) }

        it "recursively renders the child config with the parent-provided env" do
          top_level_component.config = {
            'start_index' => 1,
            'list_items' => [
              child_component,
              child_component,
              intermediate_parent_component
            ]
          }
          intermediate_parent_component.config = {
            'start_index' => 7,
            'list_items' => [
              child_component,
              child_component
            ]
          }

          expected = <<~EXPECTED
            <ul>
              <li>Item 1</li>
              <li>Item 2</li>
              <li><ul>
              <li>Item 7</li>
              <li>Item 8</li>
            </ul>
            </li>
            </ul>
          EXPECTED
          expect(exclaim_ui.render(env: env)).to eq(expected)
        end
      end
    end
  end
end
