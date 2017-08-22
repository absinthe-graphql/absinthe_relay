defmodule Absinthe.Relay.Mutation.Notation.Modern do
  @moduledoc """
  Macros used to define Mutation-related schema entities for Relay Modern.

  See `Absinthe.Relay.Mutation` for examples of use.
  """

  use Absinthe.Relay.Mutation.Notation

  defp client_mutation_id_field do
    quote do
      field :client_mutation_id, type: :string
    end
  end

end
