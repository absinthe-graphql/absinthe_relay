defmodule Absinthe.Relay do

  defmacro __using__(_opts) do
    quote do
      import Absinthe.Relay.Node, only: :macros
      import Absinthe.Relay.Connection, only: :macros
      import_types Absinthe.Relay.Connection.Types
    end
  end

end
