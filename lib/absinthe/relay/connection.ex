defmodule Absinthe.Relay.Connection do

  use Absinthe.Schema.Notation

  alias Absinthe.Schema.Notation

  @doc """
  Define a connection type for a given node type
  """
  defmacro connection({:field, _, [identifier, attrs]}, [do: block]) when is_list(attrs) do
    if attrs[:node_type] do
      do_connection_field(__CALLER__, identifier, attrs[:node_type], [], block)
    else
      raise "`connection field' requires a `:node_type` option"
    end
  end
  defmacro connection([node_type: node_type_identifier], [do: block]) do
    do_connection_definition(__CALLER__, node_type_identifier, [], block)
  end
  defmacro connection([node_type: node_type_identifier]) do
    do_connection_definition(__CALLER__, node_type_identifier, [], nil)
  end

  defmacro edge([do: _block]) do
  end

  defp do_connection_field(env, identifier, node_type_identifier, attrs, block) do
    env
    |> Notation.recordable!(:field)
    |> record_connection_field!(identifier, node_type_identifier, attrs, block)
  end

  # Generate connection & edge objects
  defp do_connection_definition(env, node_type_identifier, _, block) do
    env
    |> Notation.recordable!(:object)
    |> record_connection_definition!(node_type_identifier, block)
  end

  @doc false
  # Record a connection field
  def record_connection_field!(env, identifier, node_type_identifier, attrs, block) do
    pagination = Keyword.get(attrs, :paginate, :both)
    Notation.record_field!(
      env,
      identifier,
      [type: ident(node_type_identifier, :connection)] ++ Keyword.delete(attrs, :paginate),
      [paginate_args(pagination), block]
    )
  end

  @doc false
  # Record a connection and edge types
  def record_connection_definition!(env, node_type_identifier, nil) do
    record_connection_object!(env, node_type_identifier, [], nil)
    record_edge_object!(env, node_type_identifier, [], nil)
  end
  def record_connection_definition!(env, node_type_identifier, block) do
    record_connection_object!(env, node_type_identifier, [], block)
  end

  @doc false
  # Record the connection object
  def record_connection_object!(env, node_type_identifier, attrs, block) do
    Notation.record_object!(
      env,
      ident(node_type_identifier, :connection),
      attrs,
      [connection_object_body(node_type_identifier), block]
    )
  end

  @doc false
  # Record the edge object
  def record_edge_object!(env, node_type_identifier, attrs, block) do
    Notation.record_object!(
      env,
      ident(node_type_identifier, :edge),
      attrs,
      [edge_object_body(node_type_identifier), block]
    )
  end

  defp ident(node_type_identifier, category) do
    :"#{node_type_identifier}_#{category}"
  end

  defp connection_object_body(node_type_identifier) do
    edge_type = ident(node_type_identifier, :edge)
    quote do
      field :page_info, type: non_null(:page_info)
      field :edges, type: list_of(unquote(edge_type))
    end
  end

  defp edge_object_body(node_type_identifier) do
    quote do

      @desc "The item at the end of the edge"
      field :node, unquote(node_type_identifier)

      @desc "A cursor for use in pagination"
      field :cursor, non_null(:string)

    end
  end

  defmodule Options do
    @moduledoc false

    @typedoc false
    @type t :: %{after: nil | integer, before: nil | integer, first: nil | integer, last: nil | integer}

    defstruct after: nil, before: nil, first: nil, last: nil
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

  @empty_connection %{
    edges: [],
    page_info: %{
      start_cursor: nil,
      end_cursor: nil,
      has_previous_page: nil,
      has_next_page: nil
    }
  }

  @doc """
  Get a connection object for a list of data.

  A simple function that accepts a list and connection arguments, and returns
  a connection object for use in GraphQL.
  """
  @spec from_list(list, map) :: map
  def from_list(data, args) do
    %{after: aft, before: before, last: last, first: first} = struct(Options, args)
    count = length(data)

    begin_at = Enum.max([offset_with_default(aft, -1), -1]) + 1
    end_at = Enum.min([offset_with_default(before, count + 1), count])
    if begin_at > count || begin_at >= end_at do
      @empty_connection
    else
      first_preslice_cursor = offset_to_cursor(begin_at)
      last_preslice_cursor = offset_to_cursor(Enum.min([end_at, count]) - 1)

      end_at = if first, do: Enum.min([begin_at + first, end_at]), else: end_at
      begin_at = if last, do: Enum.map([end_at - last, begin_at]), else: begin_at

      sliced_data = Enum.slice(data, begin_at, end_at - begin_at)
      edges = sliced_data
      |> Enum.with_index
      |> Enum.map(fn
        {value, index} ->
          %{
            cursor: offset_to_cursor(begin_at + index),
            node: value
          }
      end)

      first_edge = edges |> List.first
      last_edge = edges |> List.last
      %{
        edges: edges,
        page_info: %{
          start_cursor: first_edge.cursor,
          end_cursor: last_edge.cursor,
          has_previous_page: (first_edge.cursor != first_preslice_cursor),
          has_next_page: (last_edge.cursor != last_preslice_cursor)
        }
      }
    end
  end

  @spec offset_with_default(nil | binary, integer) :: integer
  defp offset_with_default(nil, default_offset) do
    default_offset
  end
  defp offset_with_default(cursor, _) do
    cursor
    |> cursor_to_offset
  end

  @cursor_prefix "arrayconnection:"

  @doc """
  Creates the cursor string from an offset.
  """
  @spec offset_to_cursor(integer) :: binary
  def offset_to_cursor(offset) do
    [@cursor_prefix, offset]
    |> Enum.join
    |> Base.encode64
  end

  @doc """
  Rederives the offset from the cursor string.
  """
  @spec cursor_to_offset(binary) :: integer | :error
  def cursor_to_offset(cursor) do
    with {:ok, decoded} <- Base.decode64(cursor),
         {_, raw} <- String.split_at(decoded, byte_size(@cursor_prefix)),
         {parsed, _} <- Integer.parse(raw) do
      parsed
    end
  end

end
