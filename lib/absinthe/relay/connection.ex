defmodule Absinthe.Relay.Connection do
  @moduledoc """
  Support for paginated result sets.

  Define connection types that provide a standard mechanism for slicing and
  paginating result sets.

  For information about the connection model, see the Relay Cursor Connections Specification
  at https://facebook.github.io/relay/graphql/connections.htm.

  ## Connection

  Given an object type, eg:

  ```
  object :pet do
    field :name, :string
  end
  ```

  You can create a connection type to paginate them by:

  ```
  connection node_type: :pet
  ```

  This will automatically define two new types: `:pet_connection` and `:pet_edge`.

  We define a field that uses these types to paginate associated records
  by using `connection field`. Here, for instance, we support paginating a
  person's pets:

  ```
  object :person do
    field :first_name, :string
    connection field :pets, node_type: :pet do
      resolve fn
        pagination_args, %{source: person} ->
          connection = Absinthe.Relay.Connection.from_list(
            Enum.map(person.pet_ids, &pet_from_id(&1)),
            pagination_args
          )
          {:ok, connection}
        end
      end
    end
  end
  ```

  The `:pets` field is automatically set to return a `:pet_connection` type,
  and configured to accept the standard pagination arguments `after`, `before`,
  `first`, and `last`. We create the connection by using
  `Absinthe.Relay.Connection.from_list/2`, which takes a list and the pagination
  arguments passed to the resolver.

  Note: `Absinthe.Relay.Connection.from_list/2`, like `connectionFromArray` in
  the JS implementation, expects that the full list of records be materialized
  and provided -- it just discards what it doesn't need. Planned for future
  development is an implementation more like
  `connectionFromArraySlice`, intended for use in cases where you know
  the cardinality of the connection, consider it too large to
  materialize the entire array, and instead wish pass in a slice of
  the total result large enough to cover the range specified in the
  pagination arguments.

  Here's how you might request the names of the first `$petCount` pets a person
  owns:

  ```
  query FindPets($personId: ID!, $petCount: Int!) {
    person(id: $personId) {
      pets(first: $petCount) {
        pageInfo {
          hasPreviousPage
          hasNextPage
        }
        edges {
          node {
            name
          }
        }
      }
    }
  }
  ```

  `edges` here is the list of intermediary edge types (created for you
  automatically) that contain a field, `node`, that is the same `:node_type` you
  passed earlier (`:pet`).

  `pageInfo` is a field that contains information about the current view; the `startCursor`,
  `endCursor`, `hasPreviousPage`, and `hasNextPage` fields.

  ### Customizing Types

  If you'd like to add additional fields to the generated connection and edge
  types, you can do that by providing a block to the `connection` macro, eg,
  here we add a field, `:twice_edges_count` to the connection type, and another,
  `:node_name_backwards`, to the edge type:

  ```
  connection node_type: :pet do
    field :twice_edges_count, :integer do
      resolve fn
        _, %{source: conn} ->
          {:ok, length(conn.edges) * 2}
      end
    end
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

  Just remember that if you use the block form of `connection`, you must call
  the `edge` macro within the block.

  ## Macros

  For more details on connection-related macros, see
  `Absinthe.Relay.Connection.Notation`.
  """

  use Absinthe.Schema.Notation
  alias Absinthe.Schema.Notation

  defmodule Options do
    @moduledoc false

    @typedoc false
    @type t :: %{after: nil | integer, before: nil | integer, first: nil | integer, last: nil | integer}

    defstruct after: nil, before: nil, first: nil, last: nil
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
