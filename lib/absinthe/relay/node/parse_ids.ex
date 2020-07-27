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

  If a GraphQL `null` value for an ID is found, it will be passed through as
  `nil` in either case, since no type can be associated with the value.

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

    @node_id_rules [
      item_id: :item,
      interface_id: [:item, :thing],
    ]
    def middleware(middleware, _, %Absinthe.Type.Object{identifier: :query}) do
      [{Absinthe.Relay.Node.ParseIDs, @node_id_rules} | middleware]
    end
    def middleware(middleware, _, _) do
      middleware
    end

  end
  ```

  ### Using with Mutations

  Important: Remember that middleware is applied in order. If you're
  using `middleware/3` to apply this middleware to a mutation field
  (defined using the `Absinthe.Relay.Mutation` macros) _before_ the
  `Absinthe.Relay.Mutation` middleware, you need to include a wrapping
  top-level `:input`, since the argument won't be stripped out yet.

  So, this configuration defined _inside_ of a `payload field` block:

  ```
  mutation do

    payload field :change_something do

      # ...
      middleware Absinthe.Relay.Node.ParseIDs, profile: [
        user_id: :user
     ]

    end

  end
  ```

  Needs to look like this if you put the `ParseIDs` middleware first:

  ```
  def middleware(middleware, %Absinthe.Type.Field{identifier: :change_something}, _) do
    # Note the addition of the `input` level:
    [{Absinthe.Relay.Node.ParseIDs, input: [profile: [user_id: :user]]} | middleware]
  end
  def middleware(middleware, _, _) do
    middleware
  end
  ```

  If, however, you do a bit more advanced surgery to the `middleware`
  list and insert `Absinthe.Relay.Node.ParseIDs` _after_
  `Absinthe.Relay.Mutation`, you don't include the wrapping `:input`.

  ## Compatibility Note for Middleware Developers

  If you're defining a piece of middleware that modifies field
  arguments similar to `Absinthe.Relay.Mutation` does (stripping the
  outer `input` argument), you need to set the private
  `:__parse_ids_root` so that this middleware can find the root schema
  node used to apply its configuration. See `Absinthe.Relay.Mutation`
  for an example of setting the value, and the `find_schema_root!/2`
  function in this module for how it's used.
  """

  alias __MODULE__.{Config, Rule}

  @typedoc """
  The rules used to parse node ID arguments.

  ## Examples

  Declare `:item_id` as only valid with the `:item` node type:

  ```
  [
    item_id: :item
  ]
  ```

  Declare `:item_id` be valid as either `:foo` or `:bar` types:

  ```
  [
    item_id: [:foo, :bar]
  ]
  ```

  Note that using these two different forms will result in different argument
  values being passed for `:item_id` (the former, as a `binary`, the latter
  as a `map`).

  In the event that the ID is a `null`, it will be passed-through as `nil`.

  See the module documentation for more details.
  """
  @type rules :: [{atom, atom | [atom]}] | %{atom => atom | [atom]}

  @type simple_result :: nil | binary
  @type full_result :: %{type: atom, id: simple_result}
  @type result :: full_result | simple_result

  @doc false
  @spec call(Absinthe.Resolution.t(), rules) :: Absinthe.Resolution.t()
  def call(%{state: :unresolved} = resolution, rules) do
    case parse(resolution.arguments, rules, resolution) do
      {:ok, parsed_args} ->
        %{resolution | arguments: parsed_args}

      err ->
        resolution
        |> Absinthe.Resolution.put_result(err)
    end
  end

  def call(res, _) do
    res
  end

  @doc false
  @spec parse(map, rules, Absinthe.Resolution.t()) :: {:ok, map} | {:error, [String.t()]}
  def parse(args, rules, resolution) do
    config = Config.parse!(rules)
    {root, error_editor} = find_schema_root!(resolution.definition.schema_node, resolution)

    case process(config, args, resolution, root, []) do
      {processed_args, []} ->
        {:ok, processed_args}

      {_, errors} ->
        {:error, Enum.map(errors, error_editor)}
    end
  end

  # To support middleware that may run earlier and strip away toplevel arguments (eg, `Absinthe.Relay.Mutation` stripping
  # away `input`), we check for a private value on the resolution to see how to find the root schema definition.
  @spec find_schema_root!(Absinthe.Type.Field.t(), Absinthe.Resolution.t()) ::
          {{Absinthe.Type.Field.t() | Absinthe.Type.Argument.t(), String.t()},
           (String.t() -> String.t())}
  def find_schema_root!(
        %{
          __private__: [
            absinthe_relay: [
              payload: {:fill, _},
              input: {:fill, _}
            ]
          ]
        } = field,
        resolution
      ) do
    case Map.get(resolution.private, :__parse_ids_root) do
      nil ->
        {field, & &1}

      root_argument ->
        argument =
          Map.get(field.args, root_argument) ||
            raise "Can't find ParseIDs schema root argument #{inspect(root_argument)}"

        field_error_prefix = error_prefix(field, resolution.adapter)
        argument_error_prefix = error_prefix(argument, resolution.adapter)

        {argument,
         &String.replace_leading(
           &1,
           field_error_prefix,
           field_error_prefix <> argument_error_prefix
         )}
    end
  end

  def find_schema_root!(field, _resolution) do
    {field, & &1}
  end

  # Process values based on the matching configuration rules
  @spec process(Config.node_t(), any, Absinthe.Resolution.t(), Absinthe.Type.t(), list) ::
          {any, list}
  defp process(%{children: children}, args, resolution, schema_node, errors) do
    Enum.reduce(
      children,
      {args, errors},
      &reduce_namespace_child_values(&1, &2, resolution, schema_node)
    )
  end

  defp process(%Rule{} = rule, arg_values, resolution, schema_node, errors)
       when is_list(arg_values) do
    {processed, errors} =
      Enum.reduce(arg_values, {[], errors}, fn element_value, {values, errors} ->
        {processed_element_value, errors} =
          process(rule, element_value, resolution, schema_node, errors)

        {[processed_element_value | values], errors}
      end)

    {Enum.reverse(processed), errors}
  end

  defp process(%Rule{} = rule, arg_value, resolution, _schema_node, errors) do
    with {:ok, node_id} <- Absinthe.Relay.Node.from_global_id(arg_value, resolution.schema),
         {:ok, node_id} <- check_result(node_id, rule, resolution) do
      {Rule.output(rule, node_id), errors}
    else
      {:error, message} ->
        {arg_value, [message | errors]}
    end
  end

  # Since the raw value for a child may be a list, we normalize the raw value with a `List.wrap/1`, process that list,
  # then return a single value or a list of values, as appropriate, with any errors that are collected.
  @spec reduce_namespace_child_values(
          Config.node_t(),
          {any, [String.t()]},
          Absinthe.Resolution.t(),
          Absinthe.Type.t()
        ) :: {any, [String.t()]}
  defp reduce_namespace_child_values(child, {raw_values, errors}, resolution, schema_node) do
    raw_values
    |> List.wrap()
    |> Enum.reduce(
      {[], []},
      &reduce_namespace_child_value_element(child, &1, &2, resolution, schema_node)
    )
    |> case do
      {values, []} ->
        {format_child_value(raw_values, values), errors}

      {_, processed_errors} ->
        {raw_values, errors ++ processed_errors}
    end
  end

  # Process a single value for a child and collect that value with any associated errors
  @spec reduce_namespace_child_value_element(
          Config.node_t(),
          any,
          {[any], [String.t()]},
          Absinthe.Resolution.t(),
          Absinthe.Type.t()
        ) :: {[any], [String.t()]}
  defp reduce_namespace_child_value_element(
         %{key: key} = child,
         raw_value,
         {processed_values, processed_errors},
         resolution,
         schema_node
       ) do
    case Map.fetch(raw_value, key) do
      :error ->
        {[raw_value | processed_values], processed_errors}

      {:ok, raw_value_for_key} ->
        case find_child_schema_node(key, schema_node, resolution.schema) do
          nil ->
            {processed_values, ["Could not find schema_node for #{key}" | processed_errors]}

          child_schema_node ->
            {processed_value_for_key, child_errors} =
              process(child, raw_value_for_key, resolution, child_schema_node, [])

            child_errors =
              Enum.map(child_errors, &(error_prefix(child_schema_node, resolution.adapter) <> &1))

            {[Map.put(raw_value, key, processed_value_for_key) | processed_values],
             processed_errors ++ child_errors}
        end
    end
  end

  # Return a value or a list of values based on how the original raw values were structured
  @spec format_child_value(a | [a], [a]) :: a | [a] | nil when a: any
  defp format_child_value(raw_values, values) when is_list(raw_values),
    do: values |> Enum.reverse()

  defp format_child_value(_, [value]), do: value

  defp format_child_value(nil, _), do: nil

  @spec find_child_schema_node(
          Absinthe.Type.identifier_t(),
          Absinthe.Type.Field.t() | Absinthe.Type.InputObject.t() | Absinthe.Type.Argument.t(),
          Absinthe.Schema.t()
        ) :: nil | Absinthe.Type.Argument.t() | Absinthe.Type.Field.t()
  defp find_child_schema_node(identifier, %Absinthe.Type.Field{} = field, schema) do
    case Absinthe.Schema.lookup_type(schema, field.type) do
      %Absinthe.Type.InputObject{} = return_type ->
        find_child_schema_node(identifier, return_type, schema)

      _ ->
        field.args[identifier]
    end
  end

  defp find_child_schema_node(identifier, %Absinthe.Type.InputObject{} = input_object, _schema) do
    input_object.fields[identifier]
  end

  defp find_child_schema_node(identifier, %Absinthe.Type.Argument{} = argument, schema) do
    find_child_schema_node(identifier, Absinthe.Schema.lookup_type(schema, argument.type), schema)
  end

  @spec check_result(nil, Rule.t(), Absinthe.Resolution.t()) :: {:ok, nil}
  @spec check_result(full_result, Rule.t(), Absinthe.Resolution.t()) ::
          {:ok, full_result} | {:error, String.t()}
  defp check_result(nil, _rule, _resolution) do
    {:ok, nil}
  end

  defp check_result(%{type: type} = result, %Rule{expected_types: types} = rule, resolution) do
    if type in types do
      {:ok, result}
    else
      type_name =
        result.type
        |> describe_type(resolution)

      expected_types =
        Enum.map(rule.expected_types, &describe_type(&1, resolution))
        |> Enum.filter(&(&1 != nil))

      {:error, ~s<Expected node type in #{inspect(expected_types)}, found #{inspect(type_name)}.>}
    end
  end

  defp describe_type(identifier, resolution) do
    with %{name: name} <- Absinthe.Schema.lookup_type(resolution.schema, identifier) do
      name
    end
  end

  defp error_prefix(%Absinthe.Type.Argument{} = node, adapter) do
    name = node.name |> adapter.to_external_name(:argument)
    ~s<In argument "#{name}": >
  end

  defp error_prefix(%Absinthe.Type.Field{} = node, adapter) do
    name = node.name |> adapter.to_external_name(:field)
    ~s<In field "#{name}": >
  end
end
