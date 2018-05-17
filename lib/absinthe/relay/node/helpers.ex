defmodule Absinthe.Relay.Node.Helpers do
  @moduledoc """
  Useful schema helper functions for node IDs.
  """

  @doc """
  Wrap a resolver to parse node (global) ID arguments before it is executed.

  Note: This function is deprecated and will be removed in a future release. Use
  the `Absinthe.Relay.Node.ParseIDs` middleware instead.

  For each argument:

  - If a single node type is provided, the node ID in the argument map will
    be replaced by the ID specific to your application.
  - If multiple node types are provided (as a list), the node ID in the
    argument map will be replaced by a map with the node ID specific to your
    application as `:id` and the parsed node type as `:type`.

  ## Examples

  Parse a node (global) ID argument `:item_id` as an `:item` type. This replaces
  the node ID in the argument map (key `:item_id`) with your
  application-specific ID. For example, `"123"`.

  ```
  resolve parsing_node_ids(&my_field_resolver/2, item_id: :item)
  ```

  Parse a node (global) ID argument `:interface_id` into one of multiple node
  types. This replaces the node ID in the argument map (key `:interface_id`)
  with map of the parsed node type and your application-specific ID. For
  example, `%{type: :thing, id: "123"}`.

  ```
  resolve parsing_node_ids(&my_field_resolver/2, interface_id: [:item, :thing])
  ```
  """
  def parsing_node_ids(resolver, rules) do
    fn args, info ->
      Absinthe.Relay.Node.ParseIDs.parse(args, rules, info)
      |> case do
        {:ok, parsed_args} ->
          resolver.(parsed_args, info)

        error ->
          error
      end
    end
  end
end
