# frozen_string_literal: true

describe "end-to-end Exclaim::Ui behavior" do
  let(:exclaim_ui) { Exclaim::Ui.new(implementation_map: implementation_map) }
  let(:implementation_map) { Exclaim::Implementations.example_implementation_map }
  # intentional mix of explicit and shorthand declarations
  let(:ui_declaration) do
    {
      '$component' => 'vbox',
      'children' => [
        {
          '$vbox' => [
            {
              '$component' => 'paragraph',
              'sentences' => [
                {
                  '$component' => 'text',
                  'content' => { '$helper' => 'join',
                                 'items' => { '$bind' => 'numbers' },
                                 'separator' => ' + ' }
                }
              ]
            },
            {
              '$paragraph' => [
                {
                  '$text' => { '$join' => { '$bind' => 'words' },
                             'separator' => ', ' }
                },
                'Literal sentence.'
              ]
            }
          ]
        },
        {
          '$component' => 'vbox',
          'children' => [
            { '$text' => 'User:' },
            {
              '$helper' => 'if',
              'condition' => { '$bind' => 'logged_in_user' },
              'then' => { '$text' => { '$bind' => 'user.name' } },
              'else' => { '$text' => 'Guest' }
            },
            {
              '$if' => { '$bind' => 'user.account.premium' },
              'else' => { '$text' => 'Upgrade now!' }
            },
            {
              '$component' => 'each',
              'items' => [1, 2, 3],
              'yield' => 'n',
              'do' => {
                '$component' => 'image',
                'source' => { '$join' => ['https://example.com/image', { '$bind' => 'n' }, '.png'] },
                'alt' => { '$helper' => 'join',
                           'items' => ['Image', { '$bind' => 'n' }],
                           'separator' => ' ' }
              }
            }
          ]
        },
        {
          '$vbox' => [
            {
              '$component' => 'let',
              'bindings' => {
                'hello' => 'Hola',
                'good_morning' => 'Buenos Días'
              },
              'do' => {
                '$component' => 'text',
                'content' => {
                  '$helper' => 'join',
                  'items' => [{ '$bind' => 'hello' }, ', ', { '$bind' => 'good_morning' }, '.']
                }
              }
            },
            {
              '$let' => {
                'hello' => 'Salut',
                'good_morning' => 'Bonjour'
              },
              'do' => {
                '$text' => {
                  '$join' => [{ '$bind' => 'hello' }, ', ', { '$bind' => 'good_morning' }, '.']
                }
              }
            }
          ]
        }
      ]
    }
  end
  let(:env) do
    {
      'words' => ['one', 'two', 'three'],
      'numbers' => [1, 2, 3],
      'logged_in_user' => true,
      'user' => { 'name' => 'John' }
    }
  end

  it "parses and renders a UI declaration" do
    exclaim_ui.parse_ui!(ui_declaration)
    rendered_content = exclaim_ui.render(env: env)

    expected = <<~RENDERED
      <div style="display: flex; flex-flow: column">
        <div style="display: flex; flex-flow: column">
          <p>1 + 2 + 3.</p>
          <p>one, two, three. Literal sentence.</p>
        </div>
        <div style="display: flex; flex-flow: column">
          User:
          John
          Upgrade now!
          <img src="https://example.com/image1.png" alt="Image 1">
          <img src="https://example.com/image2.png" alt="Image 2">
          <img src="https://example.com/image3.png" alt="Image 3">
        </div>
        <div style="display: flex; flex-flow: column">
          Hola, Buenos Días.
          Salut, Bonjour.
        </div>
      </div>
    RENDERED
    expect(rendered_content).to eq(expected)
  end
end
