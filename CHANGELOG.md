# CHANGELOG

## 1.3.0

- Enhancement: Added `Absinthe.Relay.Node.ParseIDs` middleware. Use it instead of
  `Absinthe.Relay.Helpers.parsing_node_ids/2`, which will be removed in a future
  release.
- Enhancement: Allow multiple possible node types when parsing node IDs.
  (Thanks, @avitex.)
- Bug Fix: Handle errors when parsing multiple arguments for node IDs more
  gracefully. (Thanks to @avitex and @dpehrson.)
