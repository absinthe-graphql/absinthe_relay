defmodule Absinthe.Relay.Schema do
  @moduledoc """
  Used to extend a schema with Relay-specific macros and types.

  See `Absinthe.Relay`.
  """

  defmacro __using__ do
    do_using([], [])
  end
  defmacro __using__(flavor) when is_atom(flavor) do
    do_using(flavor, [])
  end
  defmacro __using__(opts) when is_list(opts) do
    do_using(Keyword.get(opts, :flavor, []), opts)
  end

  defp do_using(flavor, opts) do
    quote do
      use Absinthe.Relay.Schema.Notation, unquote(flavor)
      import_types Absinthe.Relay.Connection.Types
      
      def __absinthe_relay_global_id_translator__ do
        Application.get_env(Absinthe.Relay, :global_id_translator) ||
        Keyword.get(unquote(opts), :global_id_translator) ||
        Absinthe.Relay.Node.IDTranslator.Default
      end
    end
  end
end