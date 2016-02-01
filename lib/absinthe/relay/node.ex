defmodule Absinthe.Relay.Node do

  use Absinthe.Type.Definitions

  alias __MODULE__
  alias Absinthe.Type
  alias Absinthe.Execution

  @type type_resolver_t :: ((any) -> Absinthe.Type.identifier_t)
  @type object_resolver_t :: ((%{node_type: atom, id: binary}, Execution.Field.t) -> {:ok, any} | {:error, binary | [binary]})

  @doc """
  Get the Node interface given an optional type resolver

  * `type_resolver` - A function used to determine the concrete type of an
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

  * `node_interface_identifier`: The defined type for the Node interface in your
    schema
  * `resolver` - The resolver function, should expect arguments `:type` and `:id`.
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
          case Node.from_global_id(global_id) do
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

  def from_global_id(global_id) do
    case String.split(global_id, ":", parts: 2) do
      [type_name, id] ->
        try do
          type = type_name |> String.to_existing_atom
          {:ok, %{type: type, id: id}}
        rescue
          # Atom doesn't exist -- type doesn't exist
          ArgumentError ->
            {:error, "Unknown node type `#{type_name}'"}
        end
      _ ->
        {:error, "Could not parse global ID from `#{global_id}'"}
    end
  end

  def to_global_id(node_type, source_id), do: "#{node_type}:#{source_id}"

  def global_id_field(node_type_identifier, id_fetcher) do
    %Type.Field{
      name: "id",
      description: "The ID of an object",
      type: non_null(:id),
      resolve: fn
        _, %{source: source, parent_type: parent_type} = info ->
          {
            :ok,
            to_global_id(
              node_type_identifier || parent_type.name,
              id_fetcher.(info.source, info)
            )
          }
      end
    }
  end

  def global_id_field(node_type_identifier) do
    global_id_field(node_type_identifier, &default_id_fetcher/2)
  end

  defp default_id_fetcher(%{id: id}, _info), do: id

end
