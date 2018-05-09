defmodule Absinthe.Relay.Node.ParseIDs.Namespace do
  alias Absinthe.Relay.Node.ParseIDs.Config

  @enforce_keys [:key]
  defstruct [
    :key,
    children: []
  ]

  @type t :: %__MODULE__{
          key: atom,
          children: [Config.node_t()]
        }
end
