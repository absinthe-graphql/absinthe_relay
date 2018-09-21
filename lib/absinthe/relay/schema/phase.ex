defmodule Absinthe.Relay.Schema.Phase do
  use Absinthe.Phase

  alias Absinthe.Relay
  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Schema

  def run(blueprint, _) do
    {blueprint, _acc} = Blueprint.postwalk(blueprint, [], &handle_node/2)
    {:ok, blueprint}
  end

  defp handle_node(%Schema.SchemaDefinition{} = schema, acc) do
    new_types =
      for {kind, identifier, style} <- acc,
          !Enum.any?(schema.type_definitions, fn t -> t.identifier == identifier end),
          do: style.default_type(kind, identifier)

    schema = Map.update!(schema, :type_definitions, &(new_types ++ &1))
    {schema, []}
  end

  defp handle_node(%{__private__: private} = node, acc) do
    attrs = private[:absinthe_relay] || []
    fillout(attrs, node, acc)
  end

  defp handle_node(node, acc) do
    {node, acc}
  end

  defp fillout([], node, acc) do
    {node, acc}
  end

  defp fillout([{:payload, style} | attrs], node, acc) do
    payload = Relay.Schema.Notation.ident(node.identifier, :payload)
    fillout(attrs, node, [{:payload, payload, style} | acc])
  end

  defp fillout([{:input, style} | attrs], node, acc) do
    input_type = Relay.Schema.Notation.ident(node.identifier, :input)

    arg = %Schema.InputValueDefinition{
      identifier: :input,
      name: "input",
      type: %Blueprint.TypeReference.NonNull{of_type: input_type},
      module: __MODULE__,
      __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
    }

    node = %{
      node
      | arguments: [arg | node.arguments],
        middleware: [Absinthe.Relay.Mutation | node.middleware]
    }

    fillout(attrs, node, [{:input, input_type, style} | acc])
  end
end
