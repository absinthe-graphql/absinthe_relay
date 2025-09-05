# Absinthe.Relay

[![Build Status](https://github.com/absinthe-graphql/absinthe_relay/workflows/CI/badge.svg)](https://github.com/absinthe-graphql/absinthe_relay/actions?query=workflow%3ACI)
[![Version](https://img.shields.io/hexpm/v/absinthe_relay.svg)](https://hex.pm/packages/absinthe_relay)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/absinthe_relay/)
[![Download](https://img.shields.io/hexpm/dt/absinthe_relay.svg)](https://hex.pm/packages/absinthe_relay)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Last Updated](https://img.shields.io/github/last-commit/absinthe-graphql/absinthe_relay.svg)](https://github.com/absinthe-graphql/absinthe_relay/commits/master)

Support for the [Relay framework](https://facebook.github.io/relay/)
from Elixir, using the [Absinthe](https://github.com/absinthe-graphql/absinthe)
package.

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_relay):

```elixir
def deps do
  [
    {:absinthe_relay, "~> 1.5.0"}
  ]
end
```

Note: Absinthe.Relay requires Elixir 1.11 or higher.

## Upgrading

See [CHANGELOG](./CHANGELOG.md) for upgrade steps between versions.

You may want to look for the specific upgrade guide in the [Absinthe documentation](https://hexdocs.pm/absinthe).

## Documentation

See "Usage," below, for basic usage information and links to specific resources.

- [Absinthe.Relay hexdocs](https://hexdocs.pm/absinthe_relay).
- For the tutorial, guides, and general information about Absinthe-related
  projects, see [http://absinthe-graphql.org](http://absinthe-graphql.org).

## Related Projects

See the [GitHub organization](https://github.com/absinthe-graphql).

## Usage

Schemas should `use Absinthe.Relay.Schema`, optionally providing what flavor of Relay they'd like to support (`:classic` or `:modern`):

```elixir
defmodule Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  # ...

end
```

For a type module, use `Absinthe.Relay.Schema.Notation`

```elixir
defmodule Schema do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  # ...

end
```

Note that if you do not provide a flavor option, it will choose the default of `:classic`, but warn you
that this behavior will change to `:modern` in absinthe_relay v1.5.


See the documentation for [Absinthe.Relay.Node](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Node.html),
[Absinthe.Relay.Connection](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html), and [Absinthe.Relay.Mutation](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Mutation.html)  for
specific usage information.

### Node Interface

Relay
[requires an interface](https://facebook.github.io/relay/docs/en/graphql-server-specification.html#object-identification),
`"Node"`, be defined in your schema to provide a simple way to fetch
objects using a global ID scheme.

See the [Absinthe.Relay.Node](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Node.html)
module documentation for specific instructions on how do design a schema that makes use of nodes.

### Connection

Relay uses
[Connection](https://facebook.github.io/relay/docs/en/graphql-in-relay.html#connectionkey-string-filters-string)
(and other related) types to provide a standardized way of slicing and
paginating a one-to-many relationship.

Support in this package is designed to match the [Relay Cursor Connection Specification](https://facebook.github.io/relay/docs/en/graphql-server-specification.html#connections).

See the [Absinthe.Relay.Connection](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html)
module documentation for specific instructions on how do design a schema that makes use of nodes.

### Mutation

Relay supports mutation via [a contract](https://facebook.github.io/relay/docs/en/graphql-server-specification.html#mutations) involving single input object arguments (optionally for Relay Modern) with client mutation IDs (only for Relay Classic).

See the [Absinthe.Relay.Mutation](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Mutation.html) module documentation for specific instructions on how to design a schema that makes use of mutations.

### Incremental Delivery

Absinthe.Relay supports GraphQL `@defer` and `@stream` directives for incremental delivery with Relay connections. This enables streaming of connection edges while maintaining proper cursor consistency and connection structure.

Key features:
- ✅ **Relay Specification**: Full compliance with Relay Cursor Connection spec  
- ✅ **Cursor Consistency**: Maintains proper cursor ordering during streaming
- ✅ **Connection Structure**: Preserves `pageInfo` and connection metadata
- ✅ **Bidirectional Pagination**: Supports forward and backward streaming

**Installation with incremental delivery:**

```elixir
def deps do
  [
    {:absinthe, git: "https://github.com/gigsmart/absinthe.git", branch: "gigmart/defer-stream-incremental"},
    {:absinthe_relay, git: "https://github.com/gigsmart/absinthe_relay.git", branch: "gigmart/defer-stream-incremental"}
  ]
end
```

**Example usage:**

```graphql
query GetPosts($first: Int!, $after: String) {
  posts(first: $first, after: $after) @stream(initialCount: 2, label: "posts") {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        title
      }
    }
  }
}
```

For comprehensive documentation on Relay incremental delivery patterns, see [Absinthe Incremental Delivery Guide](https://hexdocs.pm/absinthe/incremental-delivery.html).

## Supporting the Babel Relay Plugin

To generate a `schema.json` file for use with the [Babel Relay Plugin](https://facebook.github.io/relay/docs/en/installation-and-setup.html#set-up-babel-plugin-relay), run the `absinthe.schema.json` Mix task, built-in to [Absinthe](https://github.com/absinthe-graphql/absinthe).

In your project, check out the documentation with:

```
mix help absinthe.schema.json
```

## Community

The project is under constant improvement by a growing list of
contributors, and your feedback is important. Please join us in Slack
(`#absinthe-graphql` under the Elixir Slack account) or the Elixir Forum
(tagged `absinthe`).

Please remember that all interactions in our official spaces follow
our [Code of Conduct](./CODE_OF_CONDUCT.md).

## Contributing

Please follow [contribution guide](./CONTRIBUTING.md).

## License

See [LICENSE.md](./LICENSE.md).
