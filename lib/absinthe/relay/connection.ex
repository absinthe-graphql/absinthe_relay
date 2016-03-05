defmodule Absinthe.Relay.Connection do

  use Absinthe.Schema.Notation

  @type cursor_t :: binary

  defmodule Options do
    @moduledoc false

    @typedoc false
    @type t :: %{after: nil | integer, before: nil | integer, first: nil | integer, last: nil | integer}

    defstruct after: nil, before: nil, first: nil, last: nil
  end

  defmodule Edge do
    @type t :: %{node: any, cursor: cursor_t}
    defstruct node: nil, cursor: nil
  end

  defmodule PageInfo do
    @type t :: %{start_cursor: cursor_t | nil, end_cursor: cursor_t | nil, has_previous_page: boolean, has_next_page: boolean}
    defstruct start_cursor: nil, end_cursor: nil, has_previous_page: nil, has_next_page: nil
  end

  @type t :: %{edges: list, page_info: PageInfo.t}
  defstruct edges: [], page_info: nil

  @doc """
  Forward pagination arguments.

  Arguments appropriate to include on a field whose type is a connection
  with forward pagination.
  """
  @spec forward_args :: %{atom => Type.Argument.t}
  def forward_args do
    Definitions.args(
      after: [type: :string],
      first: [type: :integer]
    )
  end

  @doc """
  Backward pagination arguments.

  Arguments appropriate to include on a field whose type is a connection
  with backward pagination.
  """
  @spec backward_args :: %{atom => Type.Argument.t}
  def backward_args do
    Definitions.args(
      before: [type: :string],
      last: [type: :integer]
    )
  end

  @doc """
  Pagination arguments (both forward and backward).

  Arguments appropriate to include on a field whose type is a connection
  with both forward and backward pagination.
  """
  @spec args :: %{atom => Type.Argument.t}
  def args, do: Map.merge(forward_args, backward_args)

  def type(node_type) do
    %Type.Object{fields: fields([])}
  end

  @doc """
  Get a connection object for a list of data.

  A simple function that accepts a list and connection arguments, and returns
  a connection object for use in GraphQL.
  """
  @spec from_list(list, map) :: t
  def from_list(data, args) do
    from_slice(data, args, %{slice_start: 0, data_length: length(data)})
  end

  @spec from_list(list, map, map) :: t
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
        %Edge{
          cursor: offset_to_cursor(start_offset + index),
          node: value
         }
    end)
    first_edge = edges |> List.first
    last_edge = edges |> List.last
    lower_bound = if aft, do: (after_offset + 1), else: 0
    upper_bound = if before, do: before_offset, else: data_length
    %Connection{
      edges: edges,
      page_info: %PageInfo{
        start_cursor: (if first_edge, do: first_edge.cursor, else: nil),
        end_cursor: (if last_edge, do: last_edge.cursor, else: nil),
        has_previous_page: (if last, do: start_offset > lower_bound, else: false),
        has_next_page: (if first, do: end_offset < upper_bound, else: false)
      }
    }
  end

  @spec get_offset_with_default(nil | binary, integer) :: integer
  defp get_offset_with_default(nil, default_offset) do
    default_offset
  end
  defp get_offset_with_default(cursor, default_offset) do
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

  @absinthe :type
  def edge do

  end

  @absinthe :type
  def page_info do
    %Type.Object{
      description: "Information about pagination in a connection.",
      fields: fields(
        has_next_page: [
          type: non_null(:boolean),
          description: "When paginating forwards, are there more items?"
        ],
        has_previous_page: [
          type: non_null(:boolean),
          description: "When paginating backwards, are there more items?"
        ],
        start_cursor: [
          type: :string,
          description: "When paginating backwards, the cursor to continue."
        ],
        end_cursor: [
          type: :string,
          description: "When paginating forwards, the cursor to continue."
        ]
      )
    }
  end

end
