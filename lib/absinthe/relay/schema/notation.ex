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

  @doc false
  def input(style, identifier, block) do
    quote do
      # We need to go up 2 levels so we can create the input object
      Absinthe.Schema.Notation.stash()
      Absinthe.Schema.Notation.stash()

      input_object unquote(identifier) do
        private(:absinthe_relay, :input, {:fill, unquote(style)})
        unquote(block)
      end

      # Back down to finish the field
      Absinthe.Schema.Notation.pop()
      Absinthe.Schema.Notation.pop()
    end
  end

  @doc false
  def output(style, identifier, block) do
    quote do
      Absinthe.Schema.Notation.stash()
      Absinthe.Schema.Notation.stash()

      object unquote(identifier) do
        private(:absinthe_relay, :payload, {:fill, unquote(style)})
        unquote(block)
      end

      Absinthe.Schema.Notation.pop()
      Absinthe.Schema.Notation.pop()
    end
  end

  @doc false
  def payload(meta, [field_ident | rest], block) do
    block = rewrite_input_output(field_ident, block)

    {:field, meta, [field_ident, ident(field_ident, :payload) | rest] ++ [[do: block]]}
  end

  defp rewrite_input_output(field_ident, block) do
    Macro.prewalk(block, fn
      {:input, meta, [[do: block]]} ->
        {:input, meta, [ident(field_ident, :input), [do: block]]}

      {:output, meta, [[do: block]]} ->
        {:output, meta, [ident(field_ident, :payload), [do: block]]}

      node ->
        node
    end)
  end

  @doc false
  def ident(base_identifier, category) do
    :"#{base_identifier}_#{category}"
  end
end
