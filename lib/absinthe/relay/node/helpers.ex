defmodule Absinthe.Relay.Node.Helpers do

  alias Absinthe.Relay.Node

  @doc """
  Wrap a resolver to parse node (global) ID arguments before it is executed.

  ## Examples

  Parse a node (global) ID argument `:item_id` (which should be an ID for the
  `:item` type)

  ```
  resolve parsing_node_ids(&my_field_resolver/2, item_id: :item)
  ```
  """
  def parsing_node_ids(resolver, id_keys) do
    fn args, info ->
      args = Enum.reduce(id_keys, args, fn {key, type}, args ->
        with {:ok, global_id} <- Map.fetch(args, key),
             {:ok, %{id: id, type: ^type}} <- Node.from_global_id(global_id, info.schema) do
          {:success, Map.put(args, key, id)}
        end
        |> case do
             {:ok, %{type: bad_type}} ->
               # The user provided an ID for a different type of field,
               # notify them in a normal GraphQL error response
               {:error, "Invalid node type for argument `#{key}`; should be #{type}, was #{bad_type}"}
             {:error, msg} ->
               # A more serious error, eg, a missing type, notify
               # the schema designer with an exception
               raise ArgumentError, msg
             {:success, args} ->
               args
             _ ->
               args
           end
      end)
      resolver.(args, info)
    end
  end

end
