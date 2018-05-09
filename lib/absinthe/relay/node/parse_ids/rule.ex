defmodule Absinthe.Relay.Node.ParseIDs.Rule do
  alias Absinthe.Relay.Node.ParseIDs

  @enforce_keys [:key]
  defstruct [
    :key,
    expected_types: [],
    output_mode: :full,
    schema: nil
  ]

  @type t :: %__MODULE__{
          key: atom,
          expected_types: [atom],
          output_mode: :full | :simple
        }

  @spec output(t, nil) :: nil
  @spec output(t, ParseIDs.result()) :: ParseIDs.full_result() | ParseIDs.simple_result()
  def output(_rule, nil), do: nil
  def output(%{output_mode: :full}, result), do: result
  def output(%{output_mode: :simple}, %{id: id}), do: id
end
