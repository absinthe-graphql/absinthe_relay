defmodule Absinthe.Relay.Mutation.ModernNotation do
  use Absinthe.Relay.Mutation.Base

  defp client_mutation_id_field do
    quote do
      field :client_mutation_id, type: :string
    end
  end
end
