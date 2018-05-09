defmodule Absinthe.Relay.Schema.Notation do
  @moduledoc """
  Used to extend a module where Absinthe types are defined with
  Relay-specific macros and types.

  See `Absinthe.Relay`.
  """

  @typedoc "A valid flavor"
  @type flavor :: :classic | :modern

  @valid_flavors [:classic, :modern]

  # TODO: Change to `:modern` in v1.5
  @default_flavor :classic

  @flavor_namespaces [
    modern: Modern,
    classic: Classic
  ]

  defmacro __using__(flavor) when flavor in @valid_flavors do
    notations(flavor)
  end

  defmacro __using__([]) do
    [
      # TODO: Remove warning in v1.5
      quote do
        warning = """
        Defaulting to :classic as the flavor of Relay to target. \
        Note this defaulting behavior will change to :modern in absinthe_relay v1.5. \
        To prevent seeing this notice in the meantime, explicitly provide :classic \
        or :modern as an option when you use Absinthe.Relay.Schema or \
        Absinthe.Relay.Schema.Notation. See the Absinthe.Relay @moduledoc \
        for more information. \
        """

        IO.warn(warning)
      end,
      notations(@default_flavor)
    ]
  end

  @spec notations(flavor) :: Macro.t()
  defp notations(flavor) do
    mutation_notation = Absinthe.Relay.Mutation.Notation |> flavored(flavor)

    quote do
      import Absinthe.Relay.Node.Notation, only: :macros
      import Absinthe.Relay.Node.Helpers
      import Absinthe.Relay.Connection.Notation, only: :macros
      import unquote(mutation_notation), only: :macros
    end
  end

  @spec flavored(module, flavor) :: module
  defp flavored(module, flavor) do
    Module.safe_concat(module, Keyword.fetch!(@flavor_namespaces, flavor))
  end
end
