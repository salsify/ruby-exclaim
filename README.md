# Exclaim

<!-- toc -->

- [What and Why](#what-and-why)
  * [Design Goals](#design-goals)
  * [Differences from Ember Exclaim](#differences-from-ember-exclaim)
- [Installation](#installation)
- [Usage](#usage)
  * [Configuration](#configuration)
  * [Creating an Exclaim::Ui](#creating-an-exclaimui)
  * [Implementing Components and Helpers](#implementing-components-and-helpers)
    + [Basic Examples](#basic-examples)
    + [Defining the Implementation Map](#defining-the-implementation-map)
    + [Child Components](#child-components)
    + [Variable Environments](#variable-environments)
    + [Shorthand Properties and Configuration Defaults](#shorthand-properties-and-configuration-defaults)
    + [Security Considerations](#security-considerations)
      - [Script Injection](#script-injection)
      - [Unintended Tracking/HTTP Requests](#unintended-trackinghttp-requests)
  * [Querying the Parsed UI](#querying-the-parsed-ui)
  * [Utilities](#utilities)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

<!-- tocstop -->

## What and Why

Exclaim is a JSON format to declaratively specify a UI. The JSON includes references to named UI components.
You supply the Ruby implementations of these components.

For example, here is an Exclaim declaration of a `text` component:

```
{ "$component": "text, "content": "Hello, world!" }
```

Your implementation of this `text` component could simply echo the configured `content` value:

```
->(config, env) { config['content'] }
```

The above would render the plain string `Hello, world!`

Alternatively, your implementation could wrap the `content` in an HTML `span` tag:

```
->(config, env) { "<span>#{config['content']}</span>" }
```

Then rendering the UI would produce `<span>Hello, world!</span>`

Similarly, you could implement an `image` component to replicate an HTML `img` tag:

```
->(config, env) { "<img src='#{config['source']}\' alt='#{config['alt']}'>" }
```

and declare it in JSON like so:

```
{ "$component": "image, "source": "/picture.jpg", "alt": "My Picture" }
```

These `text` and `image` components are just examples - Exclaim does not require implementing any specific components.
The needs of your domain determine the mix of components to implement.

By implementing more complex components, including ones that accept nested child components,
you prepare the building blocks to specify a full UI. Then, this library will accept JSON values representing
arbitrary UIs composed of those component references, and call your implementations to render them.

### Design Goals

Exclaim has several high-level goals:

* Enable people to declare semi-arbitrary UIs, especially people who do not have direct access to application code.
* Support variable references within these UI declarations.
* Provide the ability to offer custom, domain-specific UI components, i.e. more than what standard HTML provides.
* Represent UI declarations in a data format that is relatively easy to parse and manipulate programmatically.
* Constrain UI declarations to help avoid the XSS/CSRF vulnerabilities and automatic URL loading built into HTML.
Exclaim component implementations still must handle these issues (see [Security Considerations](#security-considerations)),
but JSON provides an easier starting point.

Other good solutions exist that fulfill slightly different needs.

* [HTML](https://developer.mozilla.org/en-US/docs/Web/HTML) itself enables declarative UIs, of course,
and with adequate input sanitization, a platform could host HTML authored by end users.
* Templating languages like [Handlebars](https://handlebarsjs.com/) or
[Liquid](https://shopify.github.io/liquid/) add variables and data transformation helpers.
* For a developer building an interactive web application,
it would be more straightforward to use any standard JavaScript framework, such as [Ember](https://emberjs.com/).
* The [Dhall](https://dhall-lang.org/) configuration language enables
safe evaluation of third-party-defined templates and functions, and has a similar spirit to Exclaim,
although it does not use JSON as its source format.

### Differences from Ember Exclaim

Salsify's [Ember Exclaim](https://github.com/salsify/ember-exclaim) JavaScript package originated the format,
and this Ruby gem aims to work compatibly with it, aside from intentional differences described below.

Ember Exclaim puts more emphasis on providing interactive UI components.
It leverages Ember [Components](https://api.emberjs.com/ember/release/classes/Component) to back
the Exclaim components referenced in the JSON, and Ember Components expressly exist
to render HTML that dynamically reacts to user actions.

In both JavaScript and Ruby, Exclaim components render in the context of a bound data environment,
but Ember Exclaim sets up two-way data binding for the components,
where user input automatically flows back into the UI's environment.

In contrast, the Ruby side focuses on one-way rendering,
with more emphasis on bulk rendering a UI for multiple data environments.
For example, at Salsify a key data entity is a product,
and this library could take a customer's UI configuration to display info about a product
and render it for each of many products (data environments).

Furthermore, this gem omits several features of
[Ember Exclaim](https://github.com/salsify/ember-exclaim):

* It does not implement `resolveFieldMeta`, `metaForField`, or `resolveMeta`.
These features are secondary to Exclaim's core functionality.
* It does not support `onChange` actions, which are more relevant for interactive components.
* It does not accept a `wrapper` component to wrap every declared component in a UI configuration,
as this is rarely required.

Please reach out if you have a concrete need for these features in Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-exclaim'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby-exclaim

## Usage

### Configuration

The only configuration option is the logger,
which expects an interface compatible with the standard Ruby
[`Logger`](https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html).
In Rails, it will default it to `Rails.logger`.

```
Exclaim.configure do |config|
  config.logger = Logger.new($stdout)
end
```

### Creating an Exclaim::Ui

We will cover how to implement components shortly.
For now, assume that you have a simple `text` component implementation,
and an _implementation map_ containing it:

````
text_component = ->(config, env) { config['content'] }
my_implementation_map = { "text" => text_component }
 ````

First, instantiate an `Exclaim::Ui`:

```
exclaim_ui = Exclaim::Ui.new(implementation_map: my_implementation_map)
```

Then, assume that you have a JSON UI configuration referencing the `text` component:

```
{ "$component": "text", "content": "Hello, world!" }
```

This JSON could be stored in your DB, fetched from a web API, or supplied any other way.

To use it with this library, the JSON must be parsed into a Ruby Hash.
Note that the hash keys must remain as type String.

```
my_ui_config = { "$component" => "text, "content" => "Hello, world!" }
```

Call the `parse_ui!` method to ingest the UI declaration, preparing it for rendering:

```
exclaim_ui.parse_ui!(my_ui_config)
```

Finally, call the `render` method to render the UI:

```
exclaim_ui.render
=> "Hello, world!"
```

The UI JSON may include `$bind` references, which act like variables:

```
{ "$component": "text, "content": { "$bind": "greeting" }  }
```

This will render with a Hash of values supplied as the _environment_ (usually abbreviated as `env`):

```
my_environment = { "greeting" => "Good morning, world!" }
exclaim_ui.render(env: my_environment)
=> "Good morning, world!"
```

Dot-separated `$bind` paths dig into nested `env` values: `a.b.c` refers to `{ "a" => { "b" => { "c" => "value" } } }`

If a `$bind` path segment is an Integer,
the library will attempt to treat it as an Array index when resolving the value at render time:

`"my_array.1"` refers to array index 1 in an `env` like `{ "my_array: ["zero", "one", ...] }`

### Implementing Components and Helpers

Note that implementations have __important [Security Considerations](#security-considerations)__.

Component implementations typically return HTML Strings.
As desired, you can leverage a Ruby templating tool like [ERB](https://rubygems.org/gems/erb)
to do this, but simple string interpolation works too.

Rendering HTML is the primary purpose of Exclaim, and in situations
when you want the UI configurations to work interchangeably in Ember and Ruby,
the Ruby component implementations will need to produce equivalent HTML to the Ember components.

However, Ruby components technically do not _need_ to return HTML Strings.
They could return some other Ruby value, like a Hash representing the JSON payload to submit to some API.

In addition to components, Exclaim also has helpers.
The distinction between components and helpers is stronger in Ember Exclaim,
since there components are Ember [Components](https://api.emberjs.com/ember/release/classes/Component),
while helpers are plain JavaScript functions.

Nevertheless, helpers have the same spirit in the Ruby version:
They do not render output directly, but instead to transform data supplied as component configuration.

As an example, suppose you define
a `coalesce` helper intended to extract the first non-nil value available from an Array.
It would support UI declarations like below, where the `text` component's `content` configuration
becomes a dynamic `pizza_topping` value from the `env`, if present, or falls back to `"plain cheese"`:

```
{
  "$component": "text",
  "content": {
    "$helper": "coalesce",
    "candidates": [{ "$bind": "pizza_topping" }, "plain cheese"]
  }
}
```

The following implementation could back this `coalesce` helper:

```
->(config, env) { config['candidates'].compact.first }
```

In Ruby Exclaim, both component and helper implementations are objects that respond to `call`,
such as a [lambda or proc](https://ruby-doc.org/core-3.0.0/Proc.html),
[`Method`](https://ruby-doc.org/core-3.0.0/Method.html) object,
or instance of a custom class which defines a `call` method.

More precisely, implementations:

* Must provide a `call` interface.
* The `call` interface must accept two positional parameters, `config` and `env`, both Hashes.
* Component implementations can optionally accept a block parameter, `&render_child`,
which the implementation can use to render child components specified in its config.
That does not apply to helper implementations.

In addition, these implementations must define either a `component?` or `helper?` predicate method.
These must return a truthy or falsy value to identify their type.

#### Basic Examples

See also the `lib/exclaim/implementations` directory for more code examples,
and `spec/integration_spec.rb` to see them in action.

Returning to the `text` component mentioned above, we could implement it a few different ways.

A lambda:

```
text_component = ->(config, env) { config['content'] }
text_component.define_singleton_method(:component?) { true }
```

Or a custom class:
```
class Text
  def call(config, env)
    config['content']
  end

  def component?
    true
  end
end

text_component = Text.new
```

If needed, a different `call`-able, such as a block or Method object:

```
def generate_implementation(is_component:, &implementation_block)
  implementation_block.define_singleton_method(:component?) { is_component }
  implementation_block
end

text_component = generate_implementation(is_component: true) do |config, env|
  config['content']
end
```

Helpers are very similar:

```
# lambda
join_helper = ->(config, env) { config['items'].to_a.join(config['separator']) }
join_helper.define_singleton_method(:helper?) { true }

# class
class Join
  def call(config, env)
    config['items'].to_a.join(config['separator'])
  end

  def helper?
    true
  end
end

join_helper = Join.new
```

Implementations may define both `component?` and `helper?`, as long as they have opposite truth-values.
They only need to define one of them, though, since one implies the converse value for the other.

#### Defining the Implementation Map

With some components and helpers implemented, an application should put them in an _implementation map_ Hash.

```
IMPLEMENTATION_MAP = {
  "text" => text_component,
  "vbox" => vbox_component,
  "list" => list_component,
  "coalesce" => coalesce_helper
  "join" => join_helper
}
```

Pass it in when instantiating an `Exclaim::Ui`:

```
exclaim_ui = Exclaim::Ui.new(implementation_map: IMPLEMENTATION_MAP)
```

This library comes with several element implementations, collected into an example implementation map.
You can freely use some or all of them, but there is no requirement to do so.
A basic assumption of Exclaim is that client code will provide a custom mix of components.

Many applications will only need a single, application-wide implementation map,
but it is quite possible to define more than one,
passing them into different `Exclaim::Ui` instances.

Example reasons why an application might define multiple implementation maps:

* One set of implementations to render HTML for public consumption,
another that draws highlights around elements for internal reviewers.
* You have two target websites that need dramatically different HTML organization or CSS classes.
* You want to implement multiple `brand_container` components that embed parallel stylesheets and logos.
* One set of implementations that renders HTML, another to render JSON payloads for an API.
* A set of implementations that should only be used with trusted UI configuration/environment values,
and another more constrained set to use with untrusted values.

Another way to accomplish the goals above would be to put conditional logic
in the implementations, and passing variable `env` Hashes to drive it when rendering.
The right strategy depends on the amount of variation and how you want to organize your implementations.

#### Child Components

Components can have nested child components, where the parent incorporates
the rendered child values into its own rendered output.

Consider a `vbox` component which renders its children in a vertically oriented `div`:

```
{
  "$component": "vbox",
  "children": [
    { "$component": "span", "content": "Child 1" },
    { "$component": "span", "content": "Child 2" }
  ]
}
```

With an implementation like this:

```
vbox_component = ->(config, env, &render_child) do
  rendered_children = config['children'].map do |child_component|
    render_child.call(child_component, env)
  end

  "<div style='display: flex; flex-flow: column'>#{rendered_children.join}</div>"
end
```

Ultimately rendering this output, assuming a simple `span` component implementation for the children:
```
<div style="display: flex; flex-flow: column"><span>Child 1</span><span>Child 2</span></div>
```

To render the children, the component implementation must accept a `&render_child` block argument
(although it may name that argument whatever it wants).

Note that Ruby lambdas cannot use the `yield` keyword, so they must reference the block argument explicitly:
```
render_child.call(child_component, env)
```

Conversely, a custom `call` method can `yield` to that block implicitly, and hence does not need to name it:
```
def call(config, env)
  rendered_children = config['children'].map do |child_component|
    yield child_component, env
  end
end
```

This illustrates the main difference between components and helpers.
Unlike components, helpers cannot take rendered components as config values.

The only narrow exception is that helpers can return un-rendered components specified in their config.
An example would be an `if` helper that evaluates a condition specified in its config.
That helper's config could also include the component declarations to return for true and false conditions.
That works, but the helper implementation cannot "touch" those components, it can only pass them through,
since it does not have access to their rendered values. (See the `if` helper in `lib/exclaim/implementations`.)

#### Variable Environments

In most of the earlier examples, implementations did not use the `env` value passed as an argument.
They only referenced their `config` argument. In fact, this library takes care of evaluating
`$bind` references from the `env` prior to handing the resolved `config` to the implementation.

However, the child component example above shows why that `env` argument exists:
When rendering child components, parent components must pass the `env` down to them:

```
render_child.call(child_component, env)
```

Actually, the parent component does not have to pass the `env` as-is when rendering the children.
The `env` is a Ruby Hash, and the implementation can vary it, either by setting a new key,
merging another Hash, or passing a separate Hash altogether.

Here is a `list` component creating a child `env` with just the item index value:

```
list_component = ->(config, env, &render_child) do
  rendered_children = config['list_items'].each_with_index.map do |child_component, idx|
    child_env = { 'n' => idx }
    value = render_child.call(child_component, child_env)
    "<li>#{value}</li>"
  end

  "<ul> #{rendered_children.join(' ')} </ul>"
end
```

Then given this UI declaration:

```
{
  "$component": "list",
  "list_items": [{ "$bind": "n" }, { "$bind": "n" }, { "$bind": "n" }] }
}
```

It would render like so, where the bound `n` varies for each item:
```
<ul> <li>0</li> <li>1</li> <li>2</li> </ul>
```

Why create a new child `env` vs. set a new key in the existing `env`, or merge another Hash onto it?

That depends on your implementations and the details of your domain.
The first guideline is to only vary the child `env` when necessary,
otherwise just pass down the original `env` when rendering child components.

When you do need to vary the child `env`, the tradeoffs are:

* Merging a new Hash onto the existing `env` means that the child components will have all the
existing `env` values plus whatever you add. This provides flexibility if you don't know exactly what child components need.
* On the other hand, merging will duplicate the Hash if you use `env.merge`, or mutate it if you use `env.merge!`
The former could allocate a lot of memory, depending on the size of the `env`
and how many nested components the UI config has. The latter could cause subtle bugs if you inadvertently
overwrite data in the parent `env`. Or if you have called `freeze` on it, mutating will raise a `FrozenError`.
* Similar concerns exist when just setting a new key on parent `env`.
* Constructing a new Hash as the child `env` may also allocate a lot of memory,
depending on the number of child components, but potentially less than duplicating the original `env`.
That avoids mutation-induced bugs as well.
* The caveat with a standalone child `env` is that if the JSON declares child component references which assume
the presence of values from an overall parent `env`, they will not exist. You may not know in advance
whether users will create declarations like that.

#### Shorthand Properties and Configuration Defaults

The JSON UI declarations can become a little verbose:

```
{
  "$component": "text",
  "content": {
    "$helper": "join,
    "items": [1, 2, 3],
    "separator": " + "
  }
}
```

This is fine when reading and writing the JSON programmatically,
but you can also let humans declare the JSON more concisely using Exclaim's shorthand syntax:

```
{
  "$text": { "$join": [1, 2, 3], "separator": " + " }
}
```

To support these shorthand properties your implementation must look for them in the config:

```
text_component = ->(config, env) { config['$text'] || config['content'] }

join_helper = ->(config, env) do
  items = (config['$join'] || config['items']).to_a
  items.join(config['separator'])
end
```

Each component or helper can only have one shorthand property,
and typically it should be the configuration value that you consider "primary."

As a related concern, you may want an implementation to supply default config values:

```
join_helper = ->(config, env) do
  items = (config['$join'] || config['items']).to_a
  separator = config['separator'] || ', '
  items.join(separator)
end
```

As a final point about shorthand declarations, note that even though
the UI configurations reference the components with a leading `$`,
that does not change anything about the implementation map.
Its keys should not start with the `$` symbol.
Both `"$text": ...` and `"$component": "text"` in UI configurations reference the `"text"` implementation map key.

#### Security Considerations

Allowing end users to declare UIs is a core goal of Exclaim,
whether they produce the JSON manually or utilize a GUI web application to compose it.

Like other systems that evaluate untrusted input, this poses a risk of security vulnerabilities.
The main concerns with Exclaim are:

* XSS or CSRF if a user can inject a `<script>` tag, or an executable HTML attribute like `onclick`.
* Unintended tracking, if the user can embed an arbitrary URL into an HTML element
that provokes automatic HTTP requests, like an `img` `src` attribute or CSS `url()` function.
* Server Side Request Forgery, if your server will render output that loads URLs, for example if you
produce a thumbnail image or PDF from rendered HTML, which will prompt fetching images/stylesheets.

Conceptually, the high-level security guidelines are:

* The UI `config` and rendering `env` are untrusted.
They intentionally contain values driven by end-users or other external parties.
* The implementations of components and helpers are trusted.
They contain arbitrary code authored by you, and will execute on your servers when rendering an arbitrary UI.

Declaring the UI `config` and `env` with JSON helps,
since it is simple to parse and has no automatically evaluated elements.
Nevertheless, since those values prompt your implementations to execute,
they can indirectly enable malicious content injection.

Thus, the goal is to define implementations that avoid that. The following points help with that:

##### Script Injection

This library HTML-escapes all resolved configuration values by default.
Assuming this `text` component implementation:

```
->(config, env) { config['content'] }
```

Then given a JSON UI declaration like this:

```
{  "$component" "text",
  "content": "<script>alert('Hello, I am executing arbitary code.');</script>"
}
```

When calling `exclaim_ui.render`, this library will pass the `config` to the implementation with the values escaped:
```
{
  "$component" "text",
  "content": "&lt;script&gt;alert(&#39;Hello, I am executing arbitary code.&#39;);&lt;/script&gt;"
}
```

The same escaping applies to values obtained from the bound `env`.

If you do need to embed raw HTML, and you are _certain_ you can trust the input,
your implementation can call `CGI.unescape_html` or `CGI.unescape_element`.
See [CGI::Util](https://ruby-doc.org/stdlib-3.0.0/libdoc/cgi/rdoc/CGI/Util.html)
in the Ruby standard library for details.

##### Unintended Tracking/HTTP Requests

If you don't need to implement components with configurable URLs, just avoid it completely.
For example, do not support arbitrary CSS snippets as configuration,
and instead enumerate some basic styling options that work for your domain.

If you do need configurable URLs, establish an allowed set of domains,
and then in your component implementation, verify that all the URL(s) in the configuration fall within that set:

```
youtube_embed_component = ->(config, env) do
  parsed_uri = URI.parse(config['source'])
  raise "Invalid Youtube URL" unless parsed_uri.host == "www.youtube.com"

  "<iframe src="#{parsed_uri}" other youtube attributes...></iframe>"
end
```

In general, component implementations can use this pattern to validate configuration.
At render time, they will receive the resolved configuration values,
after integrating bound `env` values and evaluating helpers.

Keep in mind that you may need to do this at multiple levels.
For example, `join` helper might validate the array of items in its configuration,
but a component should still validate the joined result passed to it as resolved config.

To prevent SSRF, again the simplest solution is do not render HTML on your server.
Though if you do need a feature like taking a screenshot of rendered HTML (e.g. with a headless browser),
here are some tips:

* Use the steps above to validate configuration values.
* Render the HTML within a sandboxed host that cannot access any sensitive URLs within your network.

As a similar concern to SSRF, your servers may include credentials in OS environment variables,
sensitive files, etc. Within reason, write your implementations as pure functions that only
reference the `config`, `env`, and `&render_child` arguments, and do nothing besides compute the output value.

In other words, implementations should avoid loading data from a database, making network requests,
or other actions that have different results depending on what computer executes them.

### Querying the Parsed UI

After calling `parse_ui!`, an `Exclaim::Ui` instance provides some functions to query the UI.

Given a UI declaration like so:

```
{
  "$component": "text",
  "content": {
    "$helper": "coalesce",
    "candidates": [
      { "$bind" => "a" },
      { "$bind" => "plan.b" },
      { "$bind" => "default.0" },
      "Static default"
    ]
  }
}
```

The `unique_bind_paths` method  will return
all the `$bind` paths included in the configuration:

```
exclaim_ui.unique_bind_paths
=> ["a", "plan.b", "default.0"]
```

This can be useful for checking that the UI configuration has valid `$bind` references,
or when you need to assemble the context-specific data to populate the `env`.

The `each_element` method yields each sub-Hash of the UI configuration matching
given element names. When not given a block, it returns an `Enumerator`.

The example above only has two elements, a component and a helper,
so the results are simple. This call would yield the single `coalesce` configuration:
```
exclaim_ui.each_element("coalesce").to_a
=> [{
      "$helper" => "coalesce",
      "candidates" => [
        { "$bind" => "a" },
        { "$bind" => "plan.b" },
        { "$bind" => "default.0" },
        "Static default"
      ]
    }]
```

While this call would return the top-level `text` component, which happens to be the entire UI configuration:

```
exclaim_ui.each_element("text").to_a
=> [{
      "$component" => "text",
      "content" => {
      ...
    }]
```

`each_element` also accepts the target element names as an array:

```
exclaim_ui.each_element(["text", "coalesce"]).to_a
=> [ <text config Hash>, <coalesce config sub-Hash> ]
```

When not given an `element_names` argument at all,
it enumerates _every_ Exclaim element within the UI configuration.

The `each_element` method comes in handy with more complicated, nested UI declarations.
As an example, a UI may have several `image` components at arbitrary places
throughout the UI, and you want to validate that each has `alt` text configuration:

```
exclaim_ui.each_element("image") do |image_component|
  if image_component['alt'].nil?
    Exclaim.logger.warn("Image component lacks alt configuration")
  end
end
```

It traverses the elements recursively, starting with the top-level of the UI config,
and descending down through each leaf element.
When configuration elements are Array values, it will search through each item.

### Utilities

In addition to the `Exclaim::Ui` features documented above,
this gem provides top-level utility functions.

**`Exclaim.element_name(config_hash)`**

Given a Hash including with the parsed JSON, extracts the Exclaim component or helper name.

```
Exclaim.element_name({ "$component" => "text", "content" => "Hello" })
=> "text

Exclaim.element_name({ "$text" => "Hello" })
=> "text"

Exclaim.element_name({ "no" => "exclaim element" })
=> nil
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 

To release a new version, update the version number in `version.rb`. When merged
to the default branch, [a GitHub action](.github/workflows/release.yml) will
automatically will create a git tag for the version, push git commits and tags,
and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/salsify/ruby-exclaim.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

