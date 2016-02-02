defmodule Absinthe.Relay.Node do

  use Absinthe.Type.Definitions

  alias __MODULE__
  alias Absinthe.Type
  alias Absinthe.Execution

  @type type_resolver_t :: ((any) -> Absinthe.Type.identifier_t)
  @type object_resolver_t :: ((%{node_type: atom, id: binary}, Execution.Field.t) -> {:ok, any} | {:error, binary | [binary]})
  @type id_fetcher_t :: ((any, Execution.Field.t) -> nil | binary)

  @doc """
  Get the Node interface given an optional type resolver

  - `type_resolver` - A function used to determine the concrete type of an
    object that uses the interface.
  """
  @spec interface(type_resolver_t | nil) :: Type.Interface.t
  def interface(type_resolver \\ nil) do
    %Type.Interface{
      name: "Node",
      description: "An object with an ID",
      fields: fields(
        id: [
          type: non_null(:id),
          description: "The id of the object."
        ]
      ),
      resolve_type: type_resolver
    }
  end

  @doc """
  Define the node field.

  - `node_interface_identifier`: The defined type for the Node interface in your
    schema
  - `resolver` - The resolver function, should expect arguments `:type` and `:id`.
  """
  @spec field(Absinthe.Type.identifier_t, object_resolver_t) :: Type.Field.t
  def field(node_interface_identifier, resolver) do
    %Type.Field{
      name: "ID",
      description: "Fetches an object given its ID",
      type: node_interface_identifier,
      args: args(
        id: [type: non_null(:id), description: "The id of an object."]
      ),
      resolve: fn
        %{id: global_id}, info ->
          case Node.from_global_id(global_id, info.schema) do
            {:ok, result} ->
              resolver.(result, info)
            other ->
              other
          end
      end
    }
  end

  @doc """
  Define the node field.

  * `resolver` - The resolver function, should expect arguments `:type` and `:id`.

  This assumes you've defined the Node interface in your schema as `:node`. If
  you've used another type identifier, use `node_field/2` instead.
  """
  @spec field(object_resolver_t) :: Type.Field.t
  def field(resolver) do
    field(:node, resolver)
  end

  def from_global_id(global_id, schema) do
    case Base.decode64(global_id) do
      {:ok, decoded} ->
        String.split(decoded, ":", parts: 2)
        |> do_from_global_id(decoded, schema)
      :error ->
        {:error, "Could not decode ID value `#{global_id}'"}
    end
  end

  defp do_from_global_id([type_name, id], _, schema) when byte_size(id) > 0 and byte_size(type_name) > 0 do
    case schema.types.by_name[type_name] do
      nil ->
        {:error, "Unknown type `#{type_name}'"}
      %{reference: %{identifier: ident}, interfaces: interfaces} ->
        if Enum.member?(interfaces || [], :node) do
          {:ok, %{type: ident, id: id}}
        else
          {:error, "Type `#{type_name}' is not a valid node type"}
        end
    end
  end
  defp do_from_global_id(_, decoded, _schema) do
    {:error, "Could not extract value from decoded ID `#{decoded}'"}
  end

  defp decode(value) do
    case Base.decode64(value) do
      {:ok, _} = result ->
        result
      _ ->
        {:error, ""}
    end
  end

  def to_global_id(node_type, nil) do
    {:error, "No source non-global ID value present on object"}
  end
  def to_global_id(node_type, source_id) do
    {:ok, "#{node_type}:#{source_id}" |> Base.encode64}
  end

  @doc """
  Build a global ID field for a node type using a custom ID fetcher.

  Unless the default ID fetcher (essentially `Map.get(obj, :id) |> to_string`)
  is inappropriate for your node type, use `global_id_field/1`.
  """
  @spec global_id_field(binary | atom, id_fetcher_t) :: Type.Field.t
  def global_id_field(type_identifier, id_fetcher) do
    %Type.Field{
      name: "id",
      description: "The ID of an object",
      type: non_null(:id),
      resolve: global_id_resolver(type_identifier, id_fetcher)
    }
  end

  @doc """
  Build a global ID field for a node type using the default ID fetcher.

  See `default_id_fetcher/2` for information on how raw, non-global IDs are
  retrieved by default.

  ## Examples

  Using a type name:
  ```
  global_id_field("Business")
  ```

  Using a type identifier:
  ```
  global_id_field(:business)
  ```

  ## Performance Considerations

  If using a type identifier instead of the type name, the
  type name will have to be retrieved during field resolution to
  generate the global ID.
  """
  @spec global_id_field(atom | binary) :: Type.Field.t
  def global_id_field(type_identifier) do
    global_id_field(type_identifier, &default_id_fetcher/2)
  end

  # The resolver for a global ID. If a type identifier instead of a type name
  # is used during field configuration, the type name needs to be looked up
  # during resolution.
  @spec global_id_resolver(binary | atom, id_fetcher_t) :: Type.Field.resolver_t
  defp global_id_resolver(identifier, id_fetcher) when is_atom(identifier) do
    fn obj, info ->
      type = Absinthe.Schema.lookup_type(info.schema, identifier)
      to_global_id(
        type.name,
        id_fetcher.(info.source, info)
      )
    end
  end
  defp global_id_resolver(type_name, id_fetcher) when is_binary(type_name) do
    fn _, info ->
      to_global_id(
        type_name,
        id_fetcher.(info.source, info)
      )
    end
  end

  @doc """
  The default ID fetcher used to retrieve raw, non-global IDs from values.

  * Matches `:id` out of the value.
    * If it's `nil`, it returns `nil`
    * If it's not nil, it coerces it to a binary using `Kernel.to_string/1`

  ## Examples

  ```
  iex> default_id_fetcher(%{id: "foo"})
  "foo"
  iex> default_id_fetcher(%{id: 123})
  "123"
  iex> default_id_fetcher(%{id: nil})
  nil
  iex> default_id_fetcher(%{nope: "no_id"})
  nil
  ```
  """
  @spec default_id_fetcher(any, Execution.Field.t) :: nil | binary
  def default_id_fetcher(%{id: id}, _info) when is_nil(id), do: nil
  def default_id_fetcher(%{id: id}, _info), do: id |> to_string
  def default_id_fetcher(_), do: nil

end
