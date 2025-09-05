defmodule Absinthe.Relay.Incremental.Connection do
  @moduledoc """
  Streaming support for Relay connections.
  
  This module enables @stream directive to work correctly with Relay's
  connection pattern, ensuring proper cursor handling and pagination
  with incremental delivery.
  """
  
  alias Absinthe.Relay.Connection
  
  @type stream_config :: %{
    initial_count: non_neg_integer(),
    label: String.t() | nil,
    path: list()
  }
  
  @type streaming_connection :: %{
    initial: Connection.t(),
    stream_plan: list(stream_batch()),
    total_count: non_neg_integer()
  }
  
  @type stream_batch :: %{
    edges: list(Connection.Edge.t()),
    path: list(),
    label: String.t() | nil,
    start_cursor: String.t(),
    end_cursor: String.t()
  }
  
  @doc """
  Convert a Relay connection to support streaming.
  
  This splits the connection into an initial response and a streaming plan
  for the remaining edges.
  """
  @spec stream_connection(Connection.t(), stream_config()) :: 
    {:ok, streaming_connection()} | {:error, term()}
  def stream_connection(connection, stream_config) do
    initial_count = Map.get(stream_config, :initial_count, 0)
    
    # Split edges into initial and remaining
    {initial_edges, remaining_edges} = 
      split_edges(connection.edges, initial_count)
    
    # Build initial connection with updated page info
    initial_connection = %{connection | 
      edges: initial_edges,
      page_info: update_page_info_for_streaming(
        connection.page_info,
        initial_edges,
        remaining_edges,
        connection
      )
    }
    
    # Create streaming plan for remaining edges
    stream_plan = 
      if Enum.empty?(remaining_edges) do
        []
      else
        plan_edge_streaming(remaining_edges, stream_config)
      end
    
    {:ok, %{
      initial: initial_connection,
      stream_plan: stream_plan,
      total_count: length(connection.edges)
    }}
  end
  
  @doc """
  Process a streamed batch of edges.
  
  Returns the edges formatted for incremental delivery with proper
  cursor continuity.
  """
  @spec process_stream_batch(stream_batch()) :: map()
  def process_stream_batch(batch) do
    %{
      edges: Enum.map(batch.edges, &format_edge/1),
      path: batch.path,
      label: batch.label,
      pageInfo: %{
        startCursor: batch.start_cursor,
        endCursor: batch.end_cursor
      }
    }
  end
  
  @doc """
  Validate cursor continuity across streamed batches.
  
  Ensures that cursors maintain proper ordering when edges are
  delivered incrementally.
  """
  @spec validate_cursor_continuity(list(Connection.Edge.t()), list(Connection.Edge.t())) :: 
    :ok | {:error, term()}
  def validate_cursor_continuity([], _), do: :ok
  def validate_cursor_continuity(_, []), do: :ok
  
  def validate_cursor_continuity(previous_edges, new_edges) do
    last_cursor = get_last_cursor(previous_edges)
    first_cursor = get_first_cursor(new_edges)
    
    if follows_cursor?(first_cursor, last_cursor) do
      :ok
    else
      {:error, "Cursor discontinuity detected in streamed connection"}
    end
  end
  
  @doc """
  Create a connection that supports streaming from a list of items.
  
  This is a streaming-aware version of Relay.Connection.from_list.
  """
  @spec from_list(list(), map(), Keyword.t()) :: {:ok, Connection.t()} | {:error, term()}
  def from_list(items, args, opts \\ []) do
    # Check if streaming is requested
    case Map.get(args, :stream) do
      nil ->
        # Standard connection without streaming
        Connection.from_list(items, args, opts)
        
      stream_args ->
        # Create streaming connection
        build_streaming_connection(items, args, stream_args, opts)
    end
  end
  
  @doc """
  Apply @stream directive to a connection field.
  
  This is used by the schema to mark connection fields for streaming.
  """
  @spec stream_field(atom(), Keyword.t()) :: Absinthe.Schema.Notation.field_result()
  defmacro stream_field(field_name, opts \\ []) do
    quote do
      field unquote(field_name), :connection do
        # Add streaming metadata
        meta :streaming_enabled, true
        
        # Apply options
        unquote(Keyword.get(opts, :do))
        
        # Wrap resolver with streaming support
        middleware Absinthe.Relay.Incremental.Connection.StreamingMiddleware
      end
    end
  end
  
  # Private functions
  
  defp split_edges(edges, initial_count) when initial_count >= 0 do
    {Enum.take(edges, initial_count), Enum.drop(edges, initial_count)}
  end
  
  defp update_page_info_for_streaming(page_info, initial_edges, remaining_edges, connection) do
    has_more = not Enum.empty?(remaining_edges)
    
    %{page_info | 
      # Indicate more edges are coming via streaming
      has_next_page: page_info.has_next_page or has_more,
      # Update end cursor to last initial edge if we have any
      end_cursor: get_last_cursor(initial_edges) || page_info.end_cursor,
      # Keep start cursor from first edge
      start_cursor: get_first_cursor(initial_edges) || page_info.start_cursor
    }
  end
  
  defp plan_edge_streaming(edges, config) do
    batch_size = calculate_stream_batch_size(config)
    
    edges
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.map(fn {edge_batch, index} ->
      %{
        edges: edge_batch,
        path: config.path ++ ["edges"],
        label: build_batch_label(config.label, index),
        start_cursor: get_first_cursor(edge_batch),
        end_cursor: get_last_cursor(edge_batch)
      }
    end)
  end
  
  defp calculate_stream_batch_size(config) do
    # Determine optimal batch size based on configuration
    Map.get(config, :batch_size, 10)
  end
  
  defp format_edge(edge) do
    %{
      node: edge.node,
      cursor: edge.cursor
    }
  end
  
  defp get_first_cursor([]), do: nil
  defp get_first_cursor([edge | _]), do: edge.cursor
  
  defp get_last_cursor([]), do: nil
  defp get_last_cursor(edges), do: List.last(edges).cursor
  
  defp follows_cursor?(nil, _), do: true
  defp follows_cursor?(_, nil), do: true
  defp follows_cursor?(cursor1, cursor2) do
    # Decode and compare cursors
    with {:ok, pos1} <- decode_cursor(cursor1),
         {:ok, pos2} <- decode_cursor(cursor2) do
      pos1 > pos2
    else
      _ -> false
    end
  end
  
  defp decode_cursor(cursor) do
    case Base.decode64(cursor) do
      {:ok, decoded} ->
        # Parse the position from the cursor
        case String.split(decoded, ":") do
          ["cursor", position] -> {:ok, String.to_integer(position)}
          _ -> {:error, :invalid_cursor}
        end
      error -> error
    end
  end
  
  defp build_batch_label(nil, index), do: "batch_#{index}"
  defp build_batch_label(label, index), do: "#{label}_batch_#{index}"
  
  defp build_streaming_connection(items, args, stream_args, opts) do
    # First build standard connection
    case Connection.from_list(items, Map.delete(args, :stream), opts) do
      {:ok, connection} ->
        # Then apply streaming
        stream_config = %{
          initial_count: Map.get(stream_args, :initial_count, 0),
          label: Map.get(stream_args, :label),
          path: Keyword.get(opts, :path, [])
        }
        
        stream_connection(connection, stream_config)
        
      error ->
        error
    end
  end
  
  @doc """
  Generate a streaming cursor for an item.
  
  Ensures cursor stability across incremental deliveries.
  """
  @spec generate_streaming_cursor(any(), non_neg_integer(), map()) :: String.t()
  def generate_streaming_cursor(item, index, context) do
    # Generate a stable cursor that includes:
    # - Query ID for uniqueness
    # - Index for ordering
    # - Item ID if available
    
    query_id = Map.get(context, :query_id, "default")
    item_id = get_item_id(item)
    
    cursor_data = "cursor:#{query_id}:#{index}:#{item_id}"
    Base.encode64(cursor_data)
  end
  
  defp get_item_id(item) do
    case item do
      %{id: id} -> id
      _ -> :erlang.phash2(item)
    end
  end
end

defmodule Absinthe.Relay.Incremental.Connection.StreamingMiddleware do
  @moduledoc """
  Middleware that adds streaming support to Relay connections.
  """
  
  @behaviour Absinthe.Middleware
  
  alias Absinthe.Resolution
  alias Absinthe.Relay.Incremental.Connection
  
  def call(resolution, _opts) do
    # Check if streaming is enabled for this field
    if streaming_enabled?(resolution) do
      wrap_with_streaming(resolution)
    else
      resolution
    end
  end
  
  defp streaming_enabled?(resolution) do
    # Check field metadata for streaming flag
    get_in(resolution.definition, [:meta, :streaming_enabled]) == true
  end
  
  defp wrap_with_streaming(resolution) do
    # Wrap the resolver to handle streaming
    Resolution.put_result(
      resolution,
      resolve_with_streaming(resolution)
    )
  end
  
  defp resolve_with_streaming(resolution) do
    case resolution.value do
      {:ok, %{edges: _} = connection} ->
        # Check if @stream directive is present
        case get_stream_directive(resolution) do
          nil ->
            {:ok, connection}
            
          stream_args ->
            # Apply streaming to the connection
            stream_config = %{
              initial_count: Map.get(stream_args, :initialCount, 0),
              label: Map.get(stream_args, :label),
              path: Resolution.path(resolution)
            }
            
            Connection.stream_connection(connection, stream_config)
        end
        
      other ->
        other
    end
  end
  
  defp get_stream_directive(resolution) do
    # Extract @stream directive arguments from the field
    resolution.definition
    |> Map.get(:directives, [])
    |> Enum.find(fn
      %{name: "stream"} -> true
      _ -> false
    end)
    |> case do
      %{arguments: args} -> args
      _ -> nil
    end
  end
end