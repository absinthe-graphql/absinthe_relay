defmodule Absinthe.Relay.Schema.Phase do
  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Schema
  alias Absinthe.Relay.Schema.Notation

  def run(blueprint, _) do
    {blueprint, _acc} = Blueprint.postwalk(blueprint, [], &handle_node/2)
    {:ok, blueprint}
  end

  defp handle_node(%Schema.SchemaDefinition{} = schema, acc) do
    new_types =
      for {kind, identifier, style} <- acc,
          !Enum.any?(schema.type_definitions, fn t -> t.identifier == identifier end),
          do: style.default_type(kind, identifier)

    schema =
      schema
      |> Map.update!(:type_definitions, &(new_types ++ &1))
      |> Blueprint.prewalk(&fill_nodes/1)

    {schema, []}
  end

  defp handle_node(%{__private__: private} = node, acc) do
    attrs = private[:absinthe_relay] || []
    {node, collect_types(attrs, node) ++ acc}
  end

  defp handle_node(node, acc) do
    {node, acc}
  end

  defp fill_nodes(%{__private__: private} = node) do
    Enum.reduce(private[:absinthe_relay] || [], node, fn
      {type, style}, node ->
        style.fillout(type, node)
    end)
  end

  defp fill_nodes(node) do
    node
  end

  defp collect_types(attrs, node) do
    Enum.map(attrs, fn
      {:payload, style} ->
        {:payload, Notation.ident(node.identifier, :payload), style}

      {:input, style} ->
        {:input, Notation.ident(node.identifier, :input), style}
    end)
  end
end
