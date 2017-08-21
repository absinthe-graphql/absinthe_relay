defmodule Absinthe.Relay.Schema.Notation do
  @moduledoc """
  Used to extend a module where Absinthe types are defined with
  Relay-specific macros and types.

  See `Absinthe.Relay`.
  """
  # TODO: DRY imports
  #

  def base do
    quote do
      import Absinthe.Relay.Node.Notation, only: :macros
      import Absinthe.Relay.Node.Helpers
      import Absinthe.Relay.Connection.Notation, only: :macros
    end
  end

  def classic do
    quote do
      import Absinthe.Relay.Mutation.Notation, only: :macros
      unquote(base())
    end
  end

  def modern do
    quote do
      import Absinthe.Relay.Mutation.ModernNotation, only: :macros
      unquote(base())
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmacro __using__(_opts) do
    classic()
  end
end
