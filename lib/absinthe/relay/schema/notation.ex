defmodule Absinthe.Relay.Schema.Notation do
  @moduledoc """
  Used to extend a module where Absinthe types are defined with
  Relay-specific macros and types.

  See `Absinthe.Relay`.
  """

  defmacro __using__(_opts) do
    quote do
      import Absinthe.Relay.Mutation, only: :macros
      import Absinthe.Relay.Node, only: :macros
      import Absinthe.Relay.Connection, only: :macros
    end
  end

end
