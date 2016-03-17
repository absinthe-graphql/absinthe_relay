defmodule Absinthe.Relay.Schema.Notation do

  defmacro __using__(_opts) do
    quote do
      import Absinthe.Relay.Mutation, only: :macros
      import Absinthe.Relay.Node, only: :macros
      import Absinthe.Relay.Connection, only: :macros
    end
  end

end
