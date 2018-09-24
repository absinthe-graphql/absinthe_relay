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
              edge_type_identifier: nil

    def define(node_type_identifier) do
      define(node_type_identifier, node_type_identifier)
    end

    def define(nil, nil) do
      nil
    end

    def define(node_type_identifier, nil) do
      define(node_type_identifier, node_type_identifier)
    end

    def define(node_type_identifier, base_identifier) do
      %__MODULE__{
        node_type_identifier: node_type_identifier,
        base_identifier: base_identifier,
        connection_type_identifier: ident(base_identifier, :connection),
        edge_type_identifier: ident(base_identifier, :edge)
      }
    end

    defp ident(base, category) do
      :"#{base}_#{category}"
    end
  end

  defp naming_from_attrs!(attrs) do
    naming = Naming.define(attrs[:node_type], attrs[:connection])

    naming ||
      raise(
        "Must provide a `:node_type' option (an optional `:connection` option is also supported)"
      )
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
    # do_connection_field(__CALLER__, identifier, naming_from_attrs!(attrs), field_attrs, block)
    do_connection_field(identifier, attrs, block)
  end

  defmacro connection(attrs, do: block) do
    naming = naming_from_attrs!(attrs)
    do_connection_definition(naming, attrs, block)
  end

  defmacro connection(attrs) do
    naming = naming_from_attrs!(attrs)
    do_connection_definition(naming, attrs, [])
  end

  defmacro connection(identifier, attrs, do: block) do
    naming = naming_from_attrs!(attrs |> Keyword.put(:connection, identifier))
    do_connection_definition(naming, attrs, block)
  end

  defp do_connection_field(identifier, attrs, block) do
    naming = naming_from_attrs!(attrs)

    pagination_args =
      attrs
      |> Keyword.get(:paginate, :both)
      |> paginate_args

    field_attrs =
      attrs
      |> Keyword.drop([:node_type, :connection, :paginate])
      |> Keyword.put(:type, naming.connection_type_identifier)

    quote do
      field unquote(identifier), unquote(field_attrs) do
        unquote(pagination_args)
        unquote(block)
      end
    end
  end

  defp do_connection_definition(naming, attrs, block) do
    identifier = naming.connection_type_identifier
    attrs = Keyword.drop(attrs, [:node_type, :connection])

    conn_attrs = [
      connection: naming.base_identifier,
      node_type: naming.node_type_identifier
    ]

    block = name_edge(block, conn_attrs)

    quote do
      object unquote(identifier), unquote(attrs) do
        field(:page_info, type: non_null(:page_info))
        field(:edges, type: list_of(unquote(naming.edge_type_identifier)))
        unquote(block)
      end
    end
  end

  defp name_edge([], _), do: []

  defp name_edge({:__block__, meta, content}, conn_attrs) do
    content =
      Enum.map(content, fn
        {:edge, meta, [[do: block]]} ->
          {:edge, meta, [conn_attrs, [do: block]]}

        {:edge, meta, [attrs, [do: block]]} ->
          {:edge, meta, [conn_attrs ++ attrs, [do: block]]}

        node ->
          node
      end)

    {:__block__, meta, content}
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
  """
  defmacro edge(attrs, do: block) do
    naming = naming_from_attrs!(attrs)
    attrs = Keyword.drop(attrs, [:node_type, :connection])

    quote do
      Absinthe.Schema.Notation.stash()

      object unquote(naming.edge_type_identifier), unquote(attrs) do
        @desc "The item at the end of the edge"
        field(:node, unquote(naming.node_type_identifier))
        @desc "A cursor for use in pagination"
        field(:cursor, non_null(:string))
        unquote(block)
      end

      Absinthe.Schema.Notation.pop()
    end
  end

  # @private_node_type_identifier_path [Absinthe.Relay, :connection_node]
  # @private_base_identifier_path [Absinthe.Relay, :connection_base]
  # defp do_edge(env, attrs, block) do
  #   Notation.recordable!(env, :edge, private_lookup: @private_node_type_identifier_path)
  #   # Hydrate naming struct from values stored in `private`
  #   node_type_identifier = Notation.get_in_private(env.module, @private_node_type_identifier_path)
  #   base_identifier = Notation.get_in_private(env.module, @private_base_identifier_path)
  #   naming = Naming.define(node_type_identifier, base_identifier)
  #   record_edge_object!(env, naming, attrs, block)
  # end

  defp do_connection_field(env, identifier, naming, attrs, block) do
    env
    |> Notation.recordable!(:field)
    |> record_connection_field!(identifier, naming, attrs, block)
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
    Notation.record_object!(env, naming.edge_type_identifier, attrs, [
      block,
      edge_object_body(naming, block)
    ])
  end

  defp connection_object_body(naming) do
    edge_type = naming.edge_type_identifier
    [private_category_node, private_key_node] = @private_node_type_identifier_path
    [private_category_base, private_key_base] = @private_base_identifier_path

    quote do
      field(:page_info, type: non_null(:page_info))
      field(:edges, type: list_of(unquote(edge_type)))

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
    end
  end

  defp edge_object_body(naming, block) do
    node_type = naming.node_type_identifier

    node_field =
      default_field(
        block,
        :node,
        quote do
          @desc "The item at the end of the edge"
          field(:node, unquote(node_type))
        end
      )

    cursor_field =
      default_field(
        block,
        :cursor,
        quote do
          @desc "A cursor for use in pagination"
          field(:cursor, non_null(:string))
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
      arg(:after, :string)
      arg(:first, :integer)
    end
  end

  # Backward pagination arguments.

  # Arguments appropriate to include on a field whose type is a connection
  # with backward pagination.
  defp paginate_args(:backward) do
    quote do
      arg(:before, :string)
      arg(:last, :integer)
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
