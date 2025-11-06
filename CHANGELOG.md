# Changelog

## [1.6.0](https://github.com/absinthe-graphql/absinthe_relay/compare/v1.5.2...v1.6.0) (2025-11-06)

### Miscellaneous Chores

* release 1.6.0 ([4174c0a](https://github.com/absinthe-graphql/absinthe_relay/commit/4174c0a83bea8d0fa5e3034f379acb203e01b805))
* update minimum elixir version
* update absinthe dependency mininum version

## 1.4.4 - 2018-09-20

- Feature: Enhancements to Connection macros to support extensibility of edge types. See [PR #109](https://github.com/absinthe-graphql/absinthe_relay/pull/109) (Thanks, @coderdan!)

## 1.4.3 - 2018-05-09

- Docs: Better links in generated documentation, updated links to specifications. (Thanks, @Gazler, @jackmarchant!)
- Feature: Update `Absinthe.Relay.Connection` handling of pagination information to match the latest spec. See [PR #114](https://github.com/absinthe-graphql/absinthe_relay/pull/114) for more information. (Thanks, @ndreynolds!)
- Bugfix: Better handling of errors relating to bad cursors given as arguments to `Absinthe.Relay.Connection`. See [PR #110](https://github.com/absinthe-graphql/absinthe_relay/pull/110) for more information. (Thanks, @bernardd!)
- Feature: Support overriding the global ID translators used for `Absinthe.Relay.Node`. See [PR #93](https://github.com/absinthe-graphql/absinthe_relay/pull/93) for more details. (Thanks, @avitex!)

## 1.4.2 - 2017-12-04

- Feature: Support overriding the resolver for `Absinthe.Relay.Connection` edge node fields. See [PR #99](https://github.com/absinthe-graphql/absinthe_relay/pull/99) for more details.

## 1.4.1 - 2017-11-22

- Bug Fix: Fix issue with `:modern` flavor + ParseIDs middleware. See [PR #96](https://github.com/absinthe-graphql/absinthe_relay/pull/96) for more information.

## 1.4.0 - 2017-11-13

- Feature: Support `null` values in `ParseIDs` middleware (passed through as `nil` args)
- Bug Fix: Support `null` values for `before` and `after` pagination arguments (expected by Relay Modern)

## 1.3.6 - 2017-09-13

- Type Spec Fix: Relax type constraints around `Connection.from_query`

## 1.3.5 - 2017-08-26

- Bug Fix: (Connection) Fix original issue with `from_query` where `has_next_page` wasn't correctly reported in some instances. We now request `limit + 1` records to determine if there's a next page (vs using a second count query), use the overage to determine if there are more records, and return `limit` records. See [PR #79](https://github.com/absinthe-graphql/absinthe_relay/pull/79).

## 1.3.4 - 2017-08-22

- Enhancement: (Node) Better logging support when global ID generation fails due to
  a missing local ID in the source value. See [PR #77](https://github.com/absinthe-graphql/absinthe_relay/pull/77).
- Bug Fix: (Connection) Fix issue where `has_next_page` is reported as `true` incorrectly; when the number of records and limit are the same. See [PR #76](https://github.com/absinthe-graphql/absinthe_relay/pull/76).

## 1.3.3 - 2017-08-20

- Bug Fix (Node): Fix regression with the `Absinthe.Relay.Node.ParseIDs` middleware when used in conjunction with
  the `Absinthe.Relay.Mutation` middleware. See [PR #73](https://github.com/absinthe-graphql/absinthe_relay/pull/73).
  for details.

## 1.3.2 - 2017-08-18

- Enhancement (Node): `Absinthe.Relay.Node.ParseIDs` can now decode lists of IDs. See
  the module docs, [PR #69](https://github.com/absinthe-graphql/absinthe_relay/pull/69) for details.
- Bug Fix (Connection): Make `Absinthe.Connection.from_slice/2` more forgiving if a `nil`
  value is passed in as the `offset`. See [PR #70](https://github.com/absinthe-graphql/absinthe_relay/pull/70)
  for details.

## 1.3.1 - 2017-06-15

- Enhancement (Node): `Absinthe.Relay.Node.ParseIDs` can now decode nested values! See
  the module docs for details.
- Enhancement (Node): Improved error message when node ids cannot be parsed at all.

## 1.3.0 - 2017-04-25

- Breaking Change (Connection): The functions in the `Connection` module that produce connections
  now return `{:ok, connection}` or `{:error, reason}` as they do internal error handling
  of connection related arguments

- Enhancement (Node): Added `Absinthe.Relay.Node.ParseIDs` middleware. Use it instead of
  `Absinthe.Relay.Helpers.parsing_node_ids/2`, which will be removed in a future
  release.
- Enhancement (Node): Allow multiple possible node types when parsing node IDs.
  (Thanks, @avitex.)
- Bug Fix (Node): Handle errors when parsing multiple arguments for node IDs more
  gracefully. (Thanks to @avitex and @dpehrson.)
