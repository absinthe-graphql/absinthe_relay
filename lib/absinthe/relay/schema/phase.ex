defmodule Absinthe.Relay.Schema.Phase do
  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Schema

  def run(blueprint, _) do
    blueprint = Blueprint.prewalk(blueprint, &handle_node/1)
    {:ok, blueprint}
  end

  defp handle_node(%{__private__: private} = node) do
    expand(node, private[:meta][:absinthe_relay])
  end

  defp handle_node(node), do: node

  defp expand(node, nil) do
    node
  end

  defp expand(node, attrs) do
    Enum.reduce(attrs, node, fn
      {:input, style}, node ->
        arg = %Schema.InputValueDefinition{
          identifier: :input,
          name: "input",
          type: %Blueprint.TypeReference.NonNull{of_type: style.ident(node.identifier, :input)},
          module: __MODULE__,
          __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
        }

        %{
          node
          | arguments: [arg | node.arguments],
            middleware: [Absinthe.Relay.Mutation | node.middleware]
        }
    end)
  end
end
