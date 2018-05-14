defmodule Absinthe.Relay.Connection.Options do
  @moduledoc false

  @typedoc false
  @type t :: %{
          after: nil | integer,
          before: nil | integer,
          first: nil | integer,
          last: nil | integer
        }

  defstruct after: nil, before: nil, first: nil, last: nil
end

defmodule Absinthe.Relay.Connection do
  @moduledoc """
  Support for paginated result sets.

  Define connection types that provide a standard mechanism for slicing and
  paginating result sets.

  For information about the connection model, see the Relay Cursor
  Connections Specification at
  https://facebook.github.io/relay/graphql/connections.htm.

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

  This will automatically define two new types: `:pet_connection` and
  `:pet_edge`.

  We define a field that uses these types to paginate associated records
  by using `connection field`. Here, for instance, we support paginating a
  person's pets:

  ```
  object :person do
    field :first_name, :string
    connection field :pets, node_type: :pet do
      resolve fn
        pagination_args, %{source: person} ->
          Absinthe.Relay.Connection.from_list(
            Enum.map(person.pet_ids, &pet_from_id(&1)),
            pagination_args
          )
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

  It is possible to provide additional pagination arguments to a relay
  connection:

  ```
  connection field :pets, node_type: :pet do
    arg :custom_arg, :custom
    # other args...
    resolve fn
     pagination_args_and_custom_args, %{source: person} ->
        # ... return {:ok, a_connection}
    end
  end
  ```

  Note: `Absinthe.Relay.Connection.from_list/2` expects that the full list of
  records be materialized and provided. If you're using Ecto, you probably want
  to use `Absinthe.Relay.Connection.from_query/2` instead.

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

  `pageInfo` is a field that contains information about the current
  view; the `startCursor`, `endCursor`, `hasPreviousPage`, and
  `hasNextPage` fields.

  ### Pagination Direction

  By default, connections will support bidirectional pagination, but you can
  also restrict the connection to just the `:forward` or `:backward` direction
  using the `:paginate` argument:

  ```
  connection field :pets, node_type: :pet, paginate: :forward do
  ```

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

  ### Customizing the node itself

  It's also possible to customize the way the `node` field of the
  connection's edge is resolved.  This can, for example, be useful if
  you're working with a NoSQL database that returns relationships as
  lists of IDs. Consider the following example which paginates over
  the user's account array, but resolves each one of them
  independently.

  ```
  object :account do
    field :id, non_null(:id)
    field :name, :string
  end

  connection node_type :account do
    edge do
      field :node, :account do
        resolve fn %{node: id}, _args, _info ->
          Account.find(id)
        end
      end
    end
  end

  object :user do
    field :name, string
    connection field :accounts, node_type: :account do
      resolve fn %{accounts: accounts}, _args, _info ->
        Absinthe.Relay.Connection.from_list(ids, args)
      end
    end
  end

  ```

  This would resolve the connections into a list of the user's
  associated accounts, and then for each node find that particular
  account (preferrably batched).

  ## Creating Connections

  This module provides two functions that mirror similar JavaScript functions,
  `from_list/2,3` and `from_slice/2,3`. We also provide `from_query/2,3` if you
  have Ecto as a dependency for convenience.

  Use `from_list` when you have all items in a list that you're going to
  paginate over.

  Use `from_slice` when you have items for a particular request, and merely need
  a connection produced from these items.

  ## Schema Macros

  For more details on connection-related macros, see
  `Absinthe.Relay.Connection.Notation`.
  """

  alias Absinthe.Relay.Connection.Options

  @cursor_prefix "arrayconnection:"
  @record_prefix "record:"

  @type t :: %{
          edges: [edge],
          page_info: page_info
        }

  @typedoc """
  An opaque pagination cursor

  Internally it has the base64 encoded structure:

  ```
  #{@cursor_prefix}:$offset
  ```
  """
  @type cursor :: binary

  @type edge :: %{
          node: term,
          cursor: cursor
        }

  @typedoc """
  Offset from zero.

  Negative offsets are not supported.
  """
  @type offset :: non_neg_integer
  @type limit :: non_neg_integer

  @type page_info :: %{
          start_cursor: cursor,
          end_cursor: cursor,
          has_previous_page: boolean,
          has_next_page: boolean
        }

  @doc """
  Get a connection object for a list of data.

  A simple function that accepts a list and connection arguments, and returns
  a connection object for use in GraphQL.

  The data given to it should constitute all data that further
  pagination requests may page over. As such, it may be very
  inefficient if you're pulling data from a database which could be
  used to more directly retrieve just the desired data.

  See also `from_query` and `from_slice`.

  ## Example
  ```
  #in a resolver module
  @items ~w(foo bar baz)
  def list(args, _) do
    Connection.from_list(@items, args)
  end
  ```
  """
  @spec from_list(data :: list, args :: Option.t()) :: {:ok, t} | {:error, any}
  def from_list(data, args, opts \\ []) do
    with {:ok, direction, limit} <- limit(args, opts[:max]),
         {:ok, offset} <- offset(args) do
      case offset do
        {:offset, offset} ->
          count = length(data)

          {offset, limit} =
            case direction do
              :forward ->
                {offset || 0, limit}

              :backward ->
                end_offset = offset || count
                start_offset = max(end_offset - limit, 0)
                limit = if start_offset == 0, do: end_offset, else: limit
                {start_offset, limit}
            end

          opts =
            opts
            |> Keyword.put(:has_previous_page, offset > 0)
            |> Keyword.put(:has_next_page, count > offset + limit)

          data
          |> Enum.slice(offset, limit)
          |> from_slice(offset, opts)

        {:id, value} ->
          case direction do
            :forward ->
              result_data =
                data
                |> Enum.filter(&(to_integer(&1.id) > value))

              remaining_data =
                data
                |> Enum.filter(&(to_integer(&1.id) <= value))

              opts =
                opts
                |> Keyword.put(:has_previous_page, length(remaining_data) > 0)
                |> Keyword.put(:has_next_page, length(result_data) > limit)

              result_data
              |> Enum.take(limit)
              |> from_slice(0, opts)

            :backward ->
              result_data =
                data
                |> Enum.filter(&(to_integer(&1.id) < value))

              remaining_data =
                data
                |> Enum.filter(&(to_integer(&1.id) >= value))

              opts =
                opts
                |> Keyword.put(:has_previous_page, length(result_data) > limit)
                |> Keyword.put(:has_next_page, length(remaining_data) > 0)

              result_data
              |> Enum.take(-limit)
              |> from_slice(0, opts)
          end

        {:offset, nil} ->
          opts =
            opts
            |> Keyword.put(:has_previous_page, false)
            |> Keyword.put(:has_next_page, length(data) > limit)

          data
          |> Enum.take(limit)
          |> from_slice(0, opts)
      end
    end
  end

  def to_integer(string) when is_binary(string) do
    case :string.to_integer(string) do
      {int, ""} -> int
      _ -> 0
    end
  end

  def to_integer(number) when is_number(number), do: number

  @type from_slice_opts :: [
          has_previous_page: boolean,
          has_next_page: boolean
        ]

  @type pagination_direction :: :forward | :backward

  @doc """
  Build a connection from slice

  This function assumes you have already retrieved precisely the number of items
  to be returned in this connection request.

  Often this function is used internally by other functions.

  ## Example

  This is basically how our `from_query/2` function works if we didn't need to
  worry about backwards pagination.
  ```
  # In PostResolver module
  alias Absinthe.Relay

  def list(args, %{context: %{current_user: user}}) do
    {:ok, :forward, limit} = Connection.limit(args)
    offset = Connection.offset(args)

    Post
    |> where(author_id: ^user.id)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all
    |> Relay.Connection.from_slice(offset)
  end
  ```
  """
  @spec from_slice(data :: list, offset :: offset) :: {:ok, t}
  @spec from_slice(data :: list, offset :: offset, opts :: from_slice_opts) :: {:ok, t}
  def from_slice(items, offset, opts \\ []) do
    {edges, first, last} = build_cursors(items, offset)

    page_info = %{
      start_cursor: first,
      end_cursor: last,
      has_previous_page: Keyword.get(opts, :has_previous_page, false),
      has_next_page: Keyword.get(opts, :has_next_page, false)
    }

    {:ok, %{edges: edges, page_info: page_info}}
  end

  @doc """
  Build a connection from an Ecto Query

  This will automatically set a limit and offset value on the Ecto
  query, and then run the query with whatever function is passed as
  the second argument.

  Notes:
  - Your query MUST have an `order_by` value. Offset does not make
    sense without one.
  - `last: N` must always be acompanied by either a `before:` argument
    to the query,
  or an explicit `count: ` option to the `from_query` call.
  Otherwise it is impossible to derive the required offset.

  ## Example
  ```
  # In a PostResolver module
  alias Absinthe.Relay

  def list(args, %{context: %{current_user: user}}) do
    Post
    |> where(author_id: ^user.id)
    |> Relay.Connection.from_query(&Repo.all/1, args)
  end
  ```
  """

  @type from_query_opts ::
          [
            count: non_neg_integer
          ]
          | from_slice_opts

  if Code.ensure_loaded?(Ecto) do
    @spec from_query(Ecto.Queryable.t(), (Ecto.Queryable.t() -> [term]), Options.t()) ::
            {:ok, map} | {:error, any}
    @spec from_query(
            Ecto.Queryable.t(),
            (Ecto.Queryable.t() -> [term]),
            Options.t(),
            from_query_opts
          ) :: {:ok, map} | {:error, any}
    def from_query(query, repo_fun, args, opts \\ []) do
      require Ecto.Query

      with {:ok, offset, limit} <- offset_and_limit_for_query(args, opts) do
        query =
          query
          |> Ecto.Query.limit(^(limit + 1))

        query =
          case offset do
            {:ok, {:offset, value}} ->
              query
              |> Ecto.Query.offset(^value)

            {:ok, {:id, {:forward, value}}} ->
              query
              |> Ecto.Query.where([t], t.id > ^value)

            {:ok, {:id, {:backward, value}}} ->
              query
              |> Ecto.Query.where([t], t.id < ^value)

            _ ->
              query
          end

        records =
          query
          |> Ecto.Query.offset(^offset)
          |> repo_fun.()

        opts =
          opts
          |> Keyword.put(:has_previous_page, offset > 0)
          |> Keyword.put(:has_next_page, length(records) > limit)

        from_slice(Enum.take(records, limit), offset, opts)
      end
    end
  else
    def from_query(_, _, _, _, _ \\ []) do
      raise ArgumentError, """
      Ecto not Loaded!

      You cannot use this unless Ecto is also a dependency
      """
    end
  end

  @doc false
  @spec offset_and_limit_for_query(Options.t(), from_query_opts) ::
          {:ok, offset, limit} | {:error, any}
  def offset_and_limit_for_query(args, opts) do
    with {:ok, direction, limit} <- limit(args, opts[:max]) do
      case offset(args) do
        {:ok, {:offset, offset}} ->
          case direction do
            :forward ->
              {:ok, {:offset, offset || 0}, limit}

            :backward ->
              case {offset, opts[:count]} do
                {nil, nil} ->
                  {:error,
                   "You must supply a count (total number of records) option if using `last` without `before`"}

                {nil, value} ->
                  {:ok, {:offset, max(value - limit, 0)}, limit}

                {value, _} ->
                  {:ok, {:offset, max(value - limit, 0)}, limit}
              end
          end

        {:ok, {:id, id}} ->
          {:ok, {:id, {direction, id || 0}}, limit}
      end
    end
  end

  @doc """
  Same as `limit/1` with user provided upper bound.

  Often backend developers want to provide a maximum value above which no more
  records can be retrieved, no matter how many are asked for by the front end.

  This function provides that capability. For use with `from_list` or
  `from_query` use the `:max` option on those functions.
  """
  @spec limit(args :: Options.t(), max :: pos_integer | nil) ::
          {:ok, pagination_direction, limit} | {:error, any}
  def limit(args, nil), do: limit(args)

  def limit(args, max) do
    with {:ok, direction, limit} <- limit(args) do
      {:ok, direction, min(max, limit)}
    end
  end

  @doc """
  The direction and desired number of records in the pagination arguments.
  """
  @spec limit(args :: Options.t()) :: {:ok, pagination_direction, limit} | {:error, any}
  def limit(%{first: first}), do: {:ok, :forward, first}
  def limit(%{last: last}), do: {:ok, :backward, last}
  def limit(_), do: {:error, "You must either supply `:first` or `:last`"}

  @doc """
  Returns the offset for a page.

  The limit is required because if using backwards pagination the limit will be
  subtracted from the offset.

  If no offset is specified in the pagination arguments, this will return `nil`.
  """
  @spec offset(args :: Options.t()) :: {:ok, offset | nil} | {:error, any}
  def offset(%{after: cursor}) when not is_nil(cursor) do
    case cursor_to_record(cursor) do
      {:ok, {:offset, offset}} ->
        {:ok, {:offset, offset + 1}}

      {:ok, {:id, id}} ->
        {:ok, {:id, id}}

      {:error, _} ->
        {:error, "Invalid cursor provided as `after` argument"}
    end
  end

  def offset(%{before: cursor}) when not is_nil(cursor) do
    case cursor_to_record(cursor) do
      {:ok, {:offset, offset}} ->
        {:ok, {:offset, max(offset, 1)}}

      {:ok, {:id, id}} ->
        {:ok, {:id, id}}

      {:error, _} ->
        {:error, "Invalid cursor provided as `before` argument"}
    end
  end

  def offset(_), do: {:ok, {:offset, nil}}

  defp build_cursors([], _offset), do: {[], nil, nil}

  defp build_cursors([item | items], offset) do
    offset = offset || 0
    first = record_to_cursor(item, offset)

    first_edge = %{
      node: item,
      cursor: first
    }

    {edges, last} = do_build_cursors(items, offset + 1, [first_edge], first)
    {edges, first, last}
  end

  defp do_build_cursors([], _, edges, last), do: {Enum.reverse(edges), last}

  defp do_build_cursors([item | rest], i, edges, _last) do
    cursor = record_to_cursor(item, i)

    edge = %{
      node: item,
      cursor: cursor
    }

    do_build_cursors(rest, i + 1, [edge | edges], cursor)
  end

  @doc """
  Creates the cursor string from an offset.
  """
  @spec offset_to_cursor(integer) :: binary
  def offset_to_cursor(offset) do
    [@cursor_prefix, to_string(offset)]
    |> IO.iodata_to_binary()
    |> Base.encode64()
  end

  def record_to_cursor(record, offset) do
    id = Map.get(record, :id)

    if id do
      [@record_prefix, to_string(id)]
      |> IO.iodata_to_binary()
      |> Base.encode64()
    else
      [@cursor_prefix, to_string(offset)]
      |> IO.iodata_to_binary()
      |> Base.encode64()
    end
  end

  def cursor_to_record(cursor) do
    case Base.decode64(cursor) do
      {:ok, @cursor_prefix <> raw} ->
        with {parsed, _} <- Integer.parse(raw) do
          {:ok, {:offset, parsed}}
        else
          _ -> {:error, "Invalid cursor"}
        end

      {:ok, @record_prefix <> raw} ->
        with {parsed, _} <- Integer.parse(raw) do
          {:ok, {:id, parsed}}
        else
          _ -> {:error, "Invalid cursor"}
        end

      _ ->
        {:error, "Invalid cursor"}
    end
  end

  @doc """
  Rederives the offset from the cursor string.
  """
  @spec cursor_to_offset(binary) :: integer | :error
  def cursor_to_offset(cursor) do
    with {:ok, @cursor_prefix <> raw} <- Base.decode64(cursor),
         {parsed, _} <- Integer.parse(raw) do
      {:ok, parsed}
    else
      _ -> {:error, "Invalid cursor"}
    end
  end
end
