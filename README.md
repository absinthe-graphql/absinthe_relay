# Absinthe.Relay

Support for the [Relay framework](https://facebook.github.io/relay/)
from Elixir, using the [Absinthe](https://github.com/absinthe-graphql/absinthe)
package.

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_relay):

```elixir
def deps do
  [{:absinthe_relay, "~> 1.3.0"}]
end
```

Add it to your `applications` configuration in `mix.exs`, too:

```elixir
def application do
  [applications: [:absinthe_relay]]
end
```

Note: Absinthe requires Elixir 1.4 or higher.

## Upgrading

See [CHANGELOG](./CHANGELOG.md) for upgrade steps between versions.

## Documentation

See "Usage," below, for basic usage information and links to specific resources.

- For the tutorial, guides, and general information about Absinthe-related
  projects, see [http://absinthe-graphql.org](http://absinthe-graphql.org).
- Links to the API documentation are available in the [project list](http://absinthe-graphql.org/projects).

### Roadmap

See the Roadmap on [absinthe-graphql.org](http://absinthe-graphql.org/roadmap).

## Related Projects

See the Project List on [absinthe-graphql.org](http://absinthe-graphql.org/projects).

## Usage

Schemas should `use Absinthe.Relay.Schema`, eg:

```elixir
defmodule Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema

  # ...

end
```

For a type module, use `Absinthe.Relay.Schema.Notation`

```elixir
defmodule Schema do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation

  # ...

end
```

See the documentation for [Absinthe.Relay.Node](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Node.html),
[Absinthe.Relay.Connection](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html), and [Absinthe.Relay.Mutation](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Mutation.html)  for
specific usage information.

### Node Interface

Relay
[requires an interface](https://facebook.github.io/relay/docs/graphql-object-identification.html),
`"Node"`, be defined in your schema to provide a simple way to fetch
objects using a global ID scheme.

See the [Absinthe.Relay.Node](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Node.html)
module documentation for specific instructions on how do design a schema that makes use of nodes.

### Connection

Relay uses
[Connection](http://facebook.github.io/relay/docs/graphql-connections.html)
(and other related) types to provide a standardized way of slicing and
paginating a one-to-many relationship.

Support in this package is designed to match the [Relay Cursor Connection Specification](http://facebook.github.io/relay/graphql/connections.htm).

See the [Absinthe.Relay.Connection](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html)
module documentation for specific instructions on how do design a schema that makes use of nodes.

### Mutation

Relay supports mutation via [a contract](https://facebook.github.io/relay/docs/graphql-mutations.html) involving single input object arguments with and client mutation
IDs.

Support in this package is designed to match the [Relay Input Object Mutations Specification](https://facebook.github.io/relay/graphql/mutations.htm).

See the [Absinthe.Relay.Mutation](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Mutation.html) module documentation for specific instructions on how to design a schema that makes use of mutations.

## Supporting the Babel Relay Plugin

To generate a `schema.json` file for use with the [Babel Relay Plugin](https://facebook.github.io/relay/docs/guides-babel-plugin.html#schema-json), run the `absinthe.schema.json` Mix task, built-in to [Absinthe](https://github.com/absinthe-graphql/absinthe).

In your project, check out the documentation with:

```
mix help absinthe.schema.json
```

## An Active Community

The project is under constant improvement by a growing list of contributors,
and your feedback is important. Please
[join us](http://absinthe-graphql.org/community/)!

Please remember that all interactions in our official spaces follow our [Code of
Conduct](./CODE_OF_CONDUCT.md).

## License

Released under the BSD license. See [LICENCE.md](./LICENSE.md)
