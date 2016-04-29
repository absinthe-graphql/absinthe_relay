defmodule Absinthe.Relay.Connection.Options do
  @moduledoc false

  @typedoc false
  @type t :: %{after: nil | integer, before: nil | integer, first: nil | integer, last: nil | integer}

  defstruct after: nil, before: nil, first: nil, last: nil
end

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

  alias Absinthe.Relay.Connection.Options

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
    limit = limit(args)
    offset = offset(args, limit)

    data
    |> Enum.slice(offset, offset + limit)
    |> from_slice(args, has_next_page: length(data) > (offset + limit))
  end

  @type from_slice_opts :: [
    max: pos_integer,
    has_next_page: boolean,
  ]

  @doc """
  Build a connection from slice

  This function assumes you have already retrieved precisely the number of items
  to be returned in the connection.
  """
  @spec from_slice(list, Options.t) :: map
  @spec from_slice(list, Options.t, opts :: from_slice_opts) :: map
  def from_slice(items, pagination_args, opts \\ []) do
    limit = case Keyword.fetch(opts, :max) do
      {:ok, val} -> limit(pagination_args, val)
      :error -> limit(pagination_args)
    end

    offset = offset(pagination_args, limit)

    {edges, first, last} = build_cursors(items, offset)

    has_next_page = case Keyword.fetch(opts, :has_next_page) do
      {:ok, value} -> value
      :error -> length(items) >= limit
    end

    page_info = %{
      start_cursor: first,
      end_cursor: last,
      has_previous_page: false,
      has_next_page: has_next_page,
    }
    %{edges: edges, page_info: page_info}
  end

  @doc """
  Sets the limit and offset on an Ecto Query

  ## Example
  alias Absinthe.Relay

  def connection(args, _) do
    conn =
      Post
      |> where(author_id: ^user.id)
      |> Relay.Connection.from_query(&Repo.all/1, args)
    {:ok, conn}
  end
  """
  @spec from_query(Ecto.Query.t, (Ecto.Query.t -> [term]), Options.t) :: map
  @spec from_query(Ecto.Query.t, (Ecto.Query.t -> [term]), Options.t, from_slice_opts) :: map
  def from_query(query, repo_fun, args, opts \\ [])
  if Code.ensure_loaded?(Ecto) do
    def from_query(query, repo_fun, args, opts) do
      require Ecto.Query
      limit = limit(args)
      offset = offset(args, limit)

      query
      |> Ecto.Query.limit(^limit)
      |> Ecto.Query.offset(^offset)
      |> repo_fun.()
      |> from_slice(args, opts)
    end
  else
    def from_query(_, _, _, _, _) do
      raise ArgumentError, """
      Ecto not Loaded!

      You cannot use this unless Ecto is also a dependency
      """
    end
  end

  @spec limit(Options.t, pos_integer) :: pos_integer
  def limit(args, val) do
    args
    |> limit
    |> min(val)
  end

  @doc """
  Returns the maximal number of records to retrieve
  """
  @spec limit(Options.t) :: pos_integer
  def limit(%{first: first}), do: first
  def limit(%{last: last}), do: last
  def limit(_), do: 0

  def offset(%{after: cursor}, _) do
    cursor_to_offset(cursor) + 1
  end
  def offset(%{before: cursor}, limit) do
    max(cursor_to_offset(cursor) - 1 - limit, 0)
  end
  def offset(_, _), do: 0

  defp build_cursors([], _offset), do: {[], nil, nil}
  defp build_cursors([item | items], offset) do
    first = offset_to_cursor(offset)
    first_edge = %{
      node: item,
      cursor: first
    }
    {edges, last} = do_build_cursors(items, offset + 1, [first_edge], first)
    {edges, first, last}
  end

  defp do_build_cursors([], _, edges, last), do: {Enum.reverse(edges), last}
  defp do_build_cursors([item | rest], i, edges, _last) do
    cursor = offset_to_cursor(i)
    edge = %{
      node: item,
      cursor: cursor
    }
    do_build_cursors(rest, i + 1, [edge | edges], cursor)
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
