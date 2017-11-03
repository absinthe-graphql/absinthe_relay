defmodule Absinthe.Relay.Case do
  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)
      import ExUnit.Case
    end
  end
end
