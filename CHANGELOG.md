# CHANGELOG

## 1.3.3

- Bug Fix: Fix regression with the `Absinthe.Relay.Node.ParseIDs` middleware when used in conjunction with
  the `Absinthe.Relay.Mutation` middleware. See [PR #73](https://github.com/absinthe-graphql/absinthe_relay/pull/73)
  for details.

## 1.3.2

- Enhancement: `Absinthe.Relay.Node.ParseIDs` can now decode lists of IDs. See
  the module docs, [PR #69](https://github.com/absinthe-graphql/absinthe_relay/pull/69) for details.
- Bug Fix: Make `Absinthe.Connection.from_slice/2` more forgiving if a `nil`
  value is passed in as the `offset`. See [PR #70](https://github.com/absinthe-graphql/absinthe_relay/pull/70)
  for details.

## 1.3.1

- Enhancement: `Absinthe.Relay.Node.ParseIDs` can now decode nested values! See
  the module docs for details.
- Enhancement: Improved error message when node ids cannot be parsed at all.

## 1.3.0

- Breaking Change: The functions in the `Connection` module that produce connections
  now return `{:ok, connection}` or `{:error, reason}` as they do internal error handling
  of connection related arguments

- Enhancement: Added `Absinthe.Relay.Node.ParseIDs` middleware. Use it instead of
  `Absinthe.Relay.Helpers.parsing_node_ids/2`, which will be removed in a future
  release.
- Enhancement: Allow multiple possible node types when parsing node IDs.
  (Thanks, @avitex.)
- Bug Fix: Handle errors when parsing multiple arguments for node IDs more
  gracefully. (Thanks to @avitex and @dpehrson.)
