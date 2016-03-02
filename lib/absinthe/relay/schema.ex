defmodule Absinthe.Relay.Schema do

  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema

      import Absinthe.Relay.Node, only: :macros

    end
  end

end
