defmodule Absinthe.Relay.Schema do

  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema, except: [resolve: 1]

      import Absinthe.Relay.Resolver, only: :macros
      import Absinthe.Relay.Node, only: :macros
      import Absinthe.Relay.Connection, only: :macros

      import_types Absinthe.Relay.Connection.Types

    end
  end

end
