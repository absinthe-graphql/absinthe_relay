# CHANGELOG

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
