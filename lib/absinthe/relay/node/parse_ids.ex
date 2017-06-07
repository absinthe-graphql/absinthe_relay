defmodule Absinthe.Relay.Node.ParseIDs do
  @behaviour Absinthe.Middleware

  @moduledoc """
  Parse node (global) ID arguments before they are passed to a resolver,
  checking the arguments against acceptable types.

  For each argument:

  - If a single node type is provided, the node ID in the argument map will
    be replaced by the ID specific to your application.
  - If multiple node types are provided (as a list), the node ID in the
    argument map will be replaced by a map with the node ID specific to your
    application as `:id` and the parsed node type as `:type`.

  ## Examples

  Parse a node (global) ID argument `:item_id` as an `:item` type. This replaces
  the node ID in the argument map (key `:item_id`) with your
  application-specific ID. For example, `"123"`.

  ```
  field :item, :item do
    arg :item_id, non_null(:id)

    middleware Absinthe.Relay.Node.ParseIDs, item_id: :item
    resolve &item_resolver/3
  end
  ```

  Parse a node (global) ID argument `:interface_id` into one of multiple node
  types. This replaces the node ID in the argument map (key `:interface_id`)
  with map of the parsed node type and your application-specific ID. For
  example, `%{type: :thing, id: "123"}`.

  ```
  field :foo, :foo do
    arg :interface_id, non_null(:id)

    middleware Absinthe.Relay.Node.ParseIDs, interface_id: [:item, :thing]
    resolve &foo_resolver/3
  end
  ```

  Parse a nested structure of node (global) IDs. This behaves similarly to the
  examples above, but acts recursively when given a keyword list.

  ```
  input_object :parent_input do
    field :id, non_null(:id)
    field :children, list_of(:child_input)
    field :child, non_null(:child_input)
  end

  input_object :child_input do
    field :id, non_null(:id)
  end

  mutation do
    payload field :update_parent do
      input do
        field :parent, :parent_input
      end

      output do
        field :parent, :parent
      end

      middleware Absinthe.Relay.Node.ParseIDs, parent: [
        id: :parent,
        children: [id: :child],
        child: [id: :child]
      ]
      resolve &resolve_parent/2
    end
  end
  ```

  As with any piece of middleware, this can configured schema-wide using the
  `middleware/3` function in your schema. In this example all top level
  query fields are made to support node IDs with the associated criteria in
  `@node_id_rules`:

  ```
  defmodule MyApp.Schema do

    # Schema ...

    @node_id_rules %{
      item_id: :item,
      interface_id: [:item, :thing],
    }
    def middleware(middleware, _, %Absinthe.Type.Object{identifier: :query}) do
      [{Absinthe.Relay.Node.ParseIDs, @node_id_rules} | middleware]
    end
    def middleware(middleware, _, _) do
      middleware
    end

  end
  ```

  See the documentation for `Absinthe.Middleware` for more details.
  """

  alias Absinthe.Relay.Node

  @typedoc """
  The rules used to parse node ID arguments.

  ## Examples

  Declare `:item_id` as only valid with the `:item` node type:

  ```
  %{
    item_id: :item
  }
  ```

  Declare `:item_id` be valid as either `:foo` or `:bar` types:

  ```
  %{
    item_id: [:foo, :bar]
  }
  ```

  Note that using these two different forms will result in different argument
  values being passed for `:item_id` (the former, as a `binary`, the latter
  as a `map`). See the module documentation for more details.
  """
  @type rules :: %{atom => atom | [atom]}

  @doc false
  @spec call(Absinthe.Resolution.t, rules) :: Absinthe.Resolution.t
  def call(resolution, rules) do
    case parse(resolution.arguments, rules, resolution) do
      {:ok, parsed_args} ->
        %{resolution | arguments: parsed_args}
      err ->
        resolution
        |> Absinthe.Resolution.put_result(err)
    end
  end

  @doc false
  @spec parse(map, rules, Absinthe.Resolution.t) :: {:ok, map} | {:error, [String.t]}
  def parse(args, rules, resolution) do
    case args do
      list when is_list(list) ->
        parse_list(list, rules, resolution)
      _ ->
        parse_args(args, rules, resolution)
    end
  end

  @spec parse(list, rules, Absinthe.Resolution.t) :: {:ok, map} | {:error, [String.t]}
  defp parse_list(list, rules, resolution) do
    Enum.reduce(list, {:ok, []}, fn(map, result) ->
      parse_list_item(result, map, rules, resolution)
    end)
  end

  defp parse_list_item({:error, errors} = initial_result, map, rules, resolution) do
    case parse(map, rules, resolution) do
      {:error, error} -> {:error, [error | errors]}
      _ -> initial_result
    end
  end
  defp parse_list_item({:ok, maps}, map, rules, resolution) do
    case parse(map, rules, resolution) do
      {:ok, new_map} -> {:ok, [new_map | maps]}
      {:error, error} -> {:error, [error]}
    end
  end

  @spec parse(map, rules, Absinthe.Resolution.t) :: {:ok, map} | {:error, [String.t]}
  defp parse_args(args, rules, resolution) do
    parse_all_rules(args, rules, resolution)
    |> case do
      {node_id_args, []} ->
        {:ok, Map.merge(args, node_id_args)}
      {_, errors} ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp parse_all_rules(args, rules, resolution) do
    Enum.reduce(rules, {%{}, []}, fn (rule, result) ->
      parse_rule(args, resolution, rule, result)
    end)
  end

  defp parse_rule(args, resolution, {key, _} = rule, {node_id_args, errors} = result) do
    argument_name = find_argument_name(key, resolution)

    with {:ok, global_id} <- get_global_id(args, key),
         {:ok, expected_type} <- get_expected_type(rule),
         {:ok, node_id} <- Node.from_global_id(global_id, resolution.schema),
         {:ok, node_id} <- check_node_id(node_id, expected_type, argument_name) do
      {Map.put(node_id_args, key, node_id), errors}
    else
      {:error, error} ->
        error = ~s<In argument "#{argument_name}": #{error}.>
        {node_id_args, [error | errors]}
      {:check_node_error, error} ->
        {node_id_args, [error | errors]}
      {:missing_key, _} ->
        result
      {:nested_rule, nested_rule} ->
        args
        |> Map.get(key)
        |> parse_nested_rule(resolution, nested_rule, result)
    end
  end

  defp parse_nested_rule(args, resolution, {key, rules}, {node_id_args, errors}) do
    case parse(args, rules, resolution) do
      {:ok, parsed_args} ->
        {Map.put(node_id_args, key, parsed_args), errors}
      {:error, nested_errors} ->
        {node_id_args, nested_errors ++ errors}
    end
  end

  defp get_expected_type({_, expected_type_or_nested_rule} = rule) do
    if Keyword.keyword?(expected_type_or_nested_rule) do
      {:nested_rule, rule}
    else
      {:ok, expected_type_or_nested_rule}
    end
  end

  defp get_global_id(args, key) do
    case Map.get(args, key) do
      nil ->
        {:missing_key, key}
      global_id ->
        {:ok, global_id}
    end
  end

  @spec find_argument_name(atom, Absinthe.Resolution.t) :: nil | String.t
  defp find_argument_name(identifier, resolution) do
    resolution.definition.arguments
    |> Enum.find_value(fn
      %{schema_node: %{__reference__: %{identifier: ^identifier}}} = arg ->
        arg.name
      _ ->
        false
    end)
  end

  @spec check_node_id(map, atom, String.t) :: {:ok, binary} | {:error, String.t}
  @spec check_node_id(map, [atom], String.t) :: {:ok, %{type: atom, id: binary}} | {:error, String.t}
  defp check_node_id(%{type: type} = id_map, expected_types, argument_name) when is_list(expected_types) do
    case Enum.member?(expected_types, type) do
      true ->
        {:ok, id_map}
      false ->
        {:check_node_error, ~s<In argument "#{argument_name}": Expected node type in #{inspect(expected_types)}, found #{inspect(type)}.>}
    end
  end
  defp check_node_id(%{type: expected_type, id: id}, expected_type, _) do
    {:ok, id}
  end
  defp check_node_id(%{type: type}, expected_type, argument_name) do
    {:check_node_error, ~s<In argument "#{argument_name}": Expected node type #{inspect(expected_type)}, found #{inspect(type)}.>}
  end

end
