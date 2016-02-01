defmodule Absinthe.Relay.Connection do

  use Absinthe.Type.Definitions
  alias Absinthe.Type

  @type t :: %{name: binary, type: atom, resolve_node: Absinthe.Execution.resolve_t, resolve_cursor: Absinthe.Execution.resolve_t, edge_fields: map, connection_fields: map}
  defstruct name: nil, type: nil, resolve_node: nil, resolve_cursor: nil, edge_fields: %{}, connection_fields: %{}

  @doc """

  * `:name` - Name of the connection
  * ...
  """
  @spec edge(Keyword.t) :: Absinthe.Type.Object.t
  def edge(_config) do

  end

  def object(_config) do
  end

end
