defmodule Absinthe.Relay.Node.Helpers do
  @moduledoc """
  Useful schema helper functions for node IDs.
  """

  alias Absinthe.Relay.Node

  @doc """
  Wrap a resolver to parse node (global) ID arguments before it is executed.

  For each argument:

  - If a single node type is provided, the node ID in the argument map will
    be replaced by the ID specific to your application.
  - If multiple node types are provided (as a list), the node ID in the
    argument map will be replaced by a map with the node ID specific to your
    application as `:id` and the parsed node type as `:type`.
7
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
      Enum.reduce(rules, {%{}, []}, fn {key, expected_type}, {node_id_args, errors} ->
        with {:ok, global_id} <- Map.fetch(args, key),
             {:ok, node_id} <- Node.from_global_id(global_id, info.schema),
             {:ok, node_id} <- check_node_id(node_id, expected_type, key) do
          {Map.put(node_id_args, key, node_id), errors}
        else
          {:error, msg} ->
            {node_id_args, [msg | errors]}
        end
      end)
      |> case do
        {node_id_args, []} ->
          resolver.(Map.merge(args, node_id_args), info)
        {_, errors} ->
          {:error, Enum.reverse(errors)}
      end
    end
  end

  defp check_node_id(node_id = %{ type: type }, expected_types, key) when is_list(expected_types) do
    if type in expected_types do
      {:ok, node_id}
    else
      {
        :error,
        ~s<In argument "#{key}": Expected node type in #{inspect(expected_types)}, found #{inspect(type)}.>
      }
    end
  end

  defp check_node_id(%{type: type, id: id}, expected_type, key) do
    if type == expected_type do
      {:ok, id}
    else
      {
        :error,
        ~s<In argument "#{key}": Expected node type #{inspect(expected_type)}, found #{inspect(type)}.>
      }
    end
  end
end
