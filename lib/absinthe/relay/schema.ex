defmodule Absinthe.Relay.Schema do
  @moduledoc """
  Used to extend a schema with Relay-specific macros and types.

  See `Absinthe.Relay`.
  """

  defmacro __using__(_opts) do
    quote do
      use Absinthe.Relay.Schema.Notation
      import_types Absinthe.Relay.Connection.Types
    end
  end

end
