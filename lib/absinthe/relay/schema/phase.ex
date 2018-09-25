defmodule Absinthe.Relay.Schema.Phase do
  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Schema
  alias Absinthe.Relay.Schema.Notation

  def run(blueprint, _) do
    {blueprint, _acc} = Blueprint.postwalk(blueprint, [], &collect_types/2)

    {_, acc} =
      Blueprint.prewalk(blueprint, [], fn node, acc ->
        case node do
          %Schema.FieldDefinition{identifier: identifier} = node ->
            obj =
              case hd(acc) do
                {obj, _, _} -> obj
                obj -> obj
              end

            {node, [{obj, identifier, :field} | acc]}

          %Schema.InputValueDefinition{identifier: identifier} = node ->
            obj =
              case hd(acc) do
                {obj, _, _} -> obj
                obj -> obj
              end

            {node, [{obj, identifier, :arg} | acc]}

          %{identifier: identifier} = node ->
            {node, [identifier | acc]}

          node ->
            {node, acc}
        end
      end)

    # acc |> IO.inspect()

    {:ok, blueprint}
  end

  defp collect_types(%Schema.SchemaDefinition{} = schema, new_types) do
    new_types =
      Enum.reject(new_types, fn new_type ->
        Enum.any?(schema.type_definitions, fn t -> t.identifier == new_type.identifier end)
      end)

    schema =
      schema
      |> Map.update!(:type_definitions, &(new_types ++ &1))
      |> Blueprint.prewalk(&fill_nodes/1)

    {schema, []}
  end

  defp collect_types(%{__private__: private} = node, types) do
    attrs = private[:absinthe_relay] || []

    types =
      Enum.reduce(attrs, types, fn
        {kind, {:fill, style}}, types ->
          List.wrap(style.additional_types(kind, node)) ++ types

        _, types ->
          types
      end)

    {node, types}
  end

  defp collect_types(node, acc) do
    {node, acc}
  end

  defp fill_nodes(%{__private__: private} = node) do
    Enum.reduce(private[:absinthe_relay] || [], node, fn
      {type, {:fill, style}}, node -> style.fillout(type, node)
      _, node -> node
    end)
  end

  defp fill_nodes(node) do
    node
  end
end
