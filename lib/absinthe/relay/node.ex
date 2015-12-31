defmodule Absinthe.Relay.Node do

  use Absinthe.Type.Definitions

  alias Absinthe.Type
  alias Absinthe.Execution

  @type type_resolver_t :: ((Type.Interface.t, any) -> Type.t)
  @type object_resolver_t :: ((%{id: binary}, Execution.t) -> {:ok, Type.t} | {:error, binary | [binary]})

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

  * `node_interface_type_name`: The defined type for the Node interface in your
    schema
  * `resolver` - The resolver function, should accept a map with `:id`
  """
  @spec node_field(atom, object_resolver_t) :: Type.Field.t
  def field(node_interface_type_name, resolver) do
    %Type.Field{
      name: "ID",
      description: "Fetches an object given its ID",
      type: node_interface_type_name,
      args: args(
        id: [non_null(:id), description: "The id of an object."],
      ),
      resolve: resolver
    }
  end

  @doc """
  Define the node field.

  * `resolver` - The resolver function, should accept a map with `:id`

  This assumes you've defined the Node interface in your schema as `:node`. If
  you've used another type identifier, use `node_field/2` instead.
  """
  @spec field(object_resolver_t) :: Type.Field.t
  def field(resolver) do
    field(:node, resolver)
  end

end
