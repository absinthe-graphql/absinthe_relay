defmodule Absinthe.Relay.Connection.Notation do
  @moduledoc """
  Macros used to define Connection-related schema entities

  See `Absinthe.Relay.Connection` for more information.
  """

  alias Absinthe.Schema.Notation

  defmodule Naming do
    @moduledoc false

    defstruct base_identifier: nil,
              node_type_identifier: nil,
              connection_type_identifier: nil,
              edge_type_identifier: nil,
              non_null_node_type: false

    def define(node_type_identifier) do
      define(node_type_identifier, node_type_identifier)
    end

    def define(node_type_identifier, base_identifier, opts \\ [])
    def define(nil, nil, _opts) do
      nil
    end

    def define(node_type_identifier, nil, opts) do
      define(node_type_identifier, node_type_identifier, opts)
    end

    def define(node_type_identifier, base_identifier, opts) do
      %__MODULE__{
        node_type_identifier: node_type_identifier,
        base_identifier: base_identifier,
        connection_type_identifier: ident(base_identifier, :connection),
        edge_type_identifier: ident(base_identifier, :edge),
        non_null_node_type: Keyword.get(opts, :non_null_node_type, false)
      }
    end

    defp ident(base, category) do
      :"#{base}_#{category}"
    end
  end

  defp naming_from_attrs!(attrs) do
    attrs = attrs_with_nullability(attrs)
    naming = Naming.define(attrs[:node_type], attrs[:connection], attrs)
    naming ||
      raise(
        "Must provide a `:node_type' option (an optional `:connection` option is also supported)"
      )
  end

  # If the node type is wrapped in a non_null, set the `:non_null_node_type`
  # attribute instead
  defp attrs_with_nullability(attrs) do
    case attrs[:node_type] do
      {:non_null, _, [node_type]} ->
        attrs
        |> Keyword.merge(node_type: node_type, non_null_node_type: true)
      _ ->
        attrs
    end
  end

  @doc """
  Define a connection type for a given node type.

  ## Examples

  A basic connection for a node type, `:pet`. This well generate simple
  `:pet_connection` and `:pet_edge` types for you:

  ```
  connection node_type: :pet
  ```

  You can provide a custom name for the connection type (just don't include the
  word "connection"). You must still provide the `:node_type`. You can create as
  many different connections to a node type as you want.

  This example will create a connection type, `:favorite_pets_connection`, and
  an edge type, `:favorite_pets_edge`:

  ```
  connection :favorite_pets, node_type: :pet
  ```

  You can also set the node type as non-nullable by using `non_null`:

  ```
  connection :favorite_pets, node_type: non_null(:pet)
  ```

  You can customize the connection object just like any other `object`:

  ```
  connection :favorite_pets, node_type: :pet do
    field :total_age, :float do
      resolve fn
        _, %{source: conn} ->
          sum = conn.edges
          |> Enum.map(fn edge -> edge.node.age)
          |> Enum.sum
          {:ok, sum}
      end
    end
    edge do
      # ...
    end
  end
  ```

  Just remember that if you use the block form of `connection`, you must call
  the `edge` macro within the block to make sure the edge type is generated.
  See the `edge` macro below for more information.
  """
  defmacro connection({:field, _, [identifier, attrs]}, do: block) when is_list(attrs) do
    field_attrs = Keyword.drop(attrs, [:node_type, :connection])
    do_connection_field(__CALLER__, identifier, naming_from_attrs!(attrs), field_attrs, block)
  end

  defmacro connection(attrs, do: block) do
    naming = naming_from_attrs!(attrs)
    do_connection_definition(__CALLER__, naming, [], block)
  end

  defmacro connection(identifier, attrs) do
    naming = naming_from_attrs!(attrs |> Keyword.put(:connection, identifier))
    object_attrs = attrs |> Keyword.drop([:node_type, :connection])
    do_connection_definition(__CALLER__, naming, object_attrs, nil)
  end

  defmacro connection(attrs) do
    do_connection_definition(__CALLER__, naming_from_attrs!(attrs), [], nil)
  end

  defmacro connection(identifier, attrs, do: block) do
    naming = naming_from_attrs!(attrs |> Keyword.put(:connection, identifier))
    object_attrs = attrs |> Keyword.drop([:node_type, :connection])
    do_connection_definition(__CALLER__, naming, object_attrs, block)
  end

  @doc """
  Customize the edge type.

  ## Examples

  ```
  connection node_type: :pet do
    # ...
    edge do
      field :node_name_backwards, :string do
        resolve fn
          _, %{source: edge} ->
            {:ok, edge.node.name |> String.reverse}
        end
      end
    end
  end
  ```

  You can also set the node as non-nullable by using `non_null`:

  ```
  connection node_type: non_null(:pet) do
    # ...
  end
  ```
  """
  defmacro edge(attrs, do: block) do
    __CALLER__
    |> do_edge(attrs, block)
  end

  defmacro edge(do: block) do
    __CALLER__
    |> do_edge([], block)
  end

  @private_node_type_identifier_path [Absinthe.Relay, :connection_node]
  @private_base_identifier_path [Absinthe.Relay, :connection_base]
  @private_non_null_node_type_path [Absinthe.Relay, :non_null_node_type]
  defp do_edge(env, attrs, block) do
    Notation.recordable!(env, :edge, private_lookup: @private_node_type_identifier_path)
    # Hydrate naming struct from values stored in `private`
    node_type_identifier = Notation.get_in_private(env.module, @private_node_type_identifier_path)
    base_identifier = Notation.get_in_private(env.module, @private_base_identifier_path)
    non_null_node_type =
      Notation.get_in_private(env.module, @private_non_null_node_type_path)
      |> decode_non_null_node_type_private_value()
    attrs = Keyword.put(attrs, :non_null_node_type, non_null_node_type)
    naming = Naming.define(node_type_identifier, base_identifier, attrs)
    record_edge_object!(env, naming, attrs, block)
  end

  defp do_connection_field(env, identifier, naming, attrs, block) do
    env
    |> Notation.recordable!(:field)
    |> record_connection_field!(identifier, naming, attrs, block)
  end

  # Generate connection & edge objects
  defp do_connection_definition(env, naming, attrs, block) do
    env
    |> Notation.recordable!(:object)
    |> record_connection_definition!(naming, attrs, block)
  end

  @doc false
  # Record a connection field
  def record_connection_field!(env, identifier, naming, attrs, block) do
    pagination = Keyword.get(attrs, :paginate, :both)

    Notation.record_field!(
      env,
      identifier,
      [type: naming.connection_type_identifier] ++ Keyword.delete(attrs, :paginate),
      [paginate_args(pagination), block]
    )
  end

  @doc false
  # Record a connection and edge types
  def record_connection_definition!(env, naming, attrs, nil) do
    record_connection_object!(env, naming, attrs, nil)
    record_edge_object!(env, naming, attrs, nil)
  end

  def record_connection_definition!(env, naming, attrs, block) do
    record_connection_object!(env, naming, attrs, block)
  end

  @doc false
  # Record the connection object
  def record_connection_object!(env, naming, attrs, block) do
    Notation.record_object!(env, naming.connection_type_identifier, attrs, [
      connection_object_body(naming),
      block
    ])
  end

  @doc false
  # Record the edge object
  def record_edge_object!(env, naming, attrs, block) do
    Notation.record_object!(env, naming.edge_type_identifier, Keyword.delete(attrs, :non_null_node_type), [
      block,
      edge_object_body(naming, block)
    ])
  end

  # Encode the non-null setting appropriate for storage with
  # `Absinthe.Schema.Notation.private/3`
  defp encode_non_null_node_type_private_value(false), do: :set_false
  defp encode_non_null_node_type_private_value(true), do: :set_true

  # Decode the non-null setting (see `encode_non_null_node_type_private_value/1`)
  defp decode_non_null_node_type_private_value(:set_false), do: false
  defp decode_non_null_node_type_private_value(:set_true), do: true

  defp connection_object_body(naming) do
    edge_type = naming.edge_type_identifier
    [private_category_node, private_key_node] = @private_node_type_identifier_path
    [private_category_base, private_key_base] = @private_base_identifier_path
    [private_category_non_null_node_type, private_key_non_null_node_type] = @private_non_null_node_type_path

    quote do
      field :page_info, type: non_null(:page_info)
      field :edges, type: list_of(unquote(edge_type))

      private(
        unquote(private_category_node),
        unquote(private_key_node),
        unquote(naming.node_type_identifier)
      )

      private(
        unquote(private_category_base),
        unquote(private_key_base),
        unquote(naming.base_identifier)
      )

      private(
        unquote(private_category_non_null_node_type),
        unquote(private_key_non_null_node_type),
        unquote(encode_non_null_node_type_private_value(naming.non_null_node_type))
      )
    end
  end

  defp edge_object_body(naming, block) do
    node_type =
      case naming do
        %{non_null_node_type: true} ->
          quote do
            %Absinthe.Type.NonNull{of_type: unquote(naming.node_type_identifier)}
          end

        _ ->
          naming.node_type_identifier
      end

    node_field =
      default_field(
        block,
        :node,
        quote do
          @desc "The item at the end of the edge"
          field :node, unquote(node_type)
        end
      )

    cursor_field =
      default_field(
        block,
        :cursor,
        quote do
          @desc "A cursor for use in pagination"
          field :cursor, non_null(:string)
        end
      )

    quote do
      unquote(node_field)
      unquote(cursor_field)
    end
  end

  defp default_field(definition, field, block) do
    case defines_field?(definition, field) do
      true -> nil
      false -> block
    end
  end

  defp defines_field?(ast, field_name) do
    {_, defined?} =
      Macro.prewalk(ast, false, fn
        {:field, _, [^field_name | _]}, _ = node -> {node, true}
        expr, acc -> {expr, acc}
      end)

    defined?
  end

  # Forward pagination arguments.
  #
  # Arguments appropriate to include on a field whose type is a connection
  # with forward pagination.
  defp paginate_args(:forward) do
    quote do
      arg :after, :string
      arg :first, :integer
    end
  end

  # Backward pagination arguments.

  # Arguments appropriate to include on a field whose type is a connection
  # with backward pagination.
  defp paginate_args(:backward) do
    quote do
      arg :before, :string
      arg :last, :integer
    end
  end

  # Pagination arguments (both forward and backward).

  # Arguments appropriate to include on a field whose type is a connection
  # with both forward and backward pagination.
  defp paginate_args(:both) do
    [
      paginate_args(:forward),
      paginate_args(:backward)
    ]
  end
end
