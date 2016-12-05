defmodule Absinthe.Relay.Node.Helpers do

  alias Absinthe.Relay.Node

  @doc """
  Wrap a resolver to parse node (global) ID arguments before it is executed.

  If a single type is provided, the node ID in the argument map will be replaced by the
  ID specific to your application, however if an array of types are provided, the node ID
  will be replaced by a map of the ID and type.

  ## Examples

  Parse a node (global) ID argument `:item_id` (which should be an ID for only the `:item` type).
  This replaces the node ID in the argument map (key `:item_id`) with your application specific ID.

  ```
  resolve parsing_node_ids(&my_field_resolver/2, item_id: :item)
  ```

  Parse a node (global) ID argument `:interface_id` into one of multiple ID types.
  This replaces the node ID in the argument map (key `:interface_id`) with `%{ type: type, id: id }`.

  ```
  resolve parsing_node_ids(&my_field_resolver/2, interface_id: [:item, :thing])
  ```
  """
  def parsing_node_ids(resolver, expected_id_types) do
    fn args, info ->
      try do
        args = Enum.reduce(expected_id_types, args, fn {key, expected_type}, args ->
          with {:ok, global_id} <- Map.fetch(args, key),
               {:ok, node_id} <- Node.from_global_id(global_id, info.schema),
               {:ok, node_id} <- check_node_id(node_id, expected_type, key) do
            {:ok, Map.put(args, key, node_id)}
          end
          |> case do
            {:error, msg} ->
              raise ArgumentError, msg
            {:ok, args} ->
              args
            _ ->
              args
          end
        end)
        resolver.(args, info)
      rescue
        e in ArgumentError -> {:error, e.message}
      end
    end
  end

  defp check_node_id(node_id = %{ type: type }, expected_types, key) when is_list(expected_types) do
    if type in expected_types do
      {:ok, node_id}
    else
      {:error, """
      Invalid node type for argument #{key}: #{type}
      Expected one of types: [#{Enum.join(expected_types, ",")}]
      """}
    end
  end

  defp check_node_id(%{ type: type, id: id }, expected_type, key) do
    if type == expected_type do
      {:ok, id}
    else
      {:error, """
      Invalid node type for argument #{key}: #{type}
      Expected type: #{expected_type}
      """}
    end
  end
end
