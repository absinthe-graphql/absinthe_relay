defmodule Absinthe.Relay.Connection do

  use Absinthe.Schema.Notation

  alias __MODULE__
  alias Absinthe.Schema.Notation

  @doc """
  Define a connection type for a given node type
  """
  defmacro connection({:field, _, [identifier, node_type_identifier]}, [do: block]) do
    do_connection_field(__CALLER__, identifier, node_type_identifier, [], block)
  end
  defmacro connection({:definition, _, [node_type_identifier]}, [do: block]) do
    do_connection_definition(__CALLER__, node_type_identifier, [], block)
  end
  defmacro connection({:definition, _, [node_type_identifier]}) do
    do_connection_definition(__CALLER__, node_type_identifier, [], nil)
  end
  defmacro connection(a) do
    IO.inspect(a: a)
  end
  defmacro connection(a, b) do
    IO.inspect(a: a, b: b)
  end

  defp do_connection_field(env, identifier, node_type_identifier, attrs, block) do
    env
    |> Notation.recordable!(:field)
    |> record_connection_field!(identifier, node_type_identifier, attrs, block)
  end

  # Generate connection & edge objects
  defp do_connection_definition(env, node_type_identifier, attrs, block) do
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

  @doc """
  Get a connection object for a list of data.

  A simple function that accepts a list and connection arguments, and returns
  a connection object for use in GraphQL.
  """
  @spec from_list(list, map) :: map
  def from_list(data, args) do
    from_slice(data, args, %{slice_start: 0, data_length: length(data)})
  end

  @spec from_slice(list, map, map) :: map
  def from_slice(data, args, %{slice_start: slice_start, data_length: data_length}) do
    %{after: aft, before: before, last: last, first: first} = struct(Options, args)
    slice_end = slice_start + length(data)
    before_offset = offset_with_default(before, data_length)
    after_offset = offset_with_default(aft, -1)
    start_offset = Enum.max([slice_start - 1, after_offset, -1])
    end_offset = Enum.min([slice_end, before_offset, data_length])
    if first, do: end_offset = Enum.min([end_offset, start_offset + first])
    if last, do: start_offset = Enum.max([start_offset, end_offset - last])
    # If supplied slice is too large, trim it down before mapping over it.
    slice = Enum.slice(
      data,
      Enum.max([start_offset - slice_start, 0]),
      length(data) - (slice_end - end_offset)
    )
    edges = slice
    |> Enum.with_index
    |> Enum.map(fn
      {value, index} ->
        %{
          cursor: offset_to_cursor(start_offset + index),
          node: value
         }
    end)
    first_edge = edges |> List.first
    last_edge = edges |> List.last
    lower_bound = if aft, do: (after_offset + 1), else: 0
    upper_bound = if before, do: before_offset, else: data_length
    %{
      edges: edges,
      page_info: %{
        start_cursor: (if first_edge, do: first_edge.cursor, else: nil),
        end_cursor: (if last_edge, do: last_edge.cursor, else: nil),
        has_previous_page: (if last, do: start_offset > lower_bound, else: false),
        has_next_page: (if first, do: end_offset < upper_bound, else: false)
      }
    }
  end

  @spec offset_with_default(nil | binary, integer) :: integer
  defp offset_with_default(nil, default_offset) do
    default_offset
  end
  defp offset_with_default(cursor, default_offset) do
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
