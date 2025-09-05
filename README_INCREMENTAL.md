# Absinthe Relay Incremental Delivery

Relay connection support for GraphQL `@defer` and `@stream` directives.

## Overview

This package extends `absinthe_relay` to support incremental delivery with Relay-style connections. Stream edges incrementally while maintaining cursor consistency and proper connection structure throughout the streaming process.

## Features

- ✅ **Relay Specification**: Full compliance with Relay Cursor Connection spec
- ✅ **Cursor Consistency**: Maintains proper cursor ordering during streaming
- ✅ **Connection Structure**: Preserves `pageInfo` and connection metadata
- ✅ **Bidirectional Pagination**: Supports forward and backward streaming
- ✅ **Error Resilience**: Graceful handling of partial failures

## Installation

This functionality is included when using both `absinthe_relay` and incremental delivery:

```elixir
def deps do
  [
    {:absinthe, "~> 1.8"},
    {:absinthe_relay, "~> 1.5"}
  ]
end
```

## Basic Usage

### Schema Definition

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern
  
  import_types Absinthe.Type.BuiltIns
  
  connection node_type: :post
  connection node_type: :user
  
  query do
    connection field :posts, node_type: :post do
      arg :category, :string
      
      resolve fn args, _ ->
        # Your existing connection resolver
        MyApp.Resolvers.list_posts(args)
      end
    end
    
    field :user, :user do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.get_user/2
    end
  end
  
  object :user do
    field :id, non_null(:id)
    field :name, non_null(:string)
    
    connection field :posts, node_type: :post do
      resolve fn user, args, _ ->
        MyApp.Resolvers.user_posts(user, args)
      end
    end
  end
  
  node object :post do
    field :id, non_null(:id)
    field :title, non_null(:string)  
    field :content, :string
    field :published_at, :datetime
  end
end
```

### Streaming Connections

#### Basic Streaming

```graphql
query GetPosts($first: Int!, $after: String) {
  posts(first: $first, after: $after) @stream(initialCount: 2, label: "posts") {
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    edges {
      cursor
      node {
        id
        title
        publishedAt
      }
    }
  }
}
```

#### Streaming with Deferred Node Data

```graphql
query GetPostsWithDetails($first: Int!) {
  posts(first: $first) @stream(initialCount: 3, label: "posts") {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id  
        title
        # Defer expensive content loading
        ... @defer(label: "content") {
          content
          author {
            name
            avatar
          }
        }
      }
    }
  }
}
```

#### Nested Connection Streaming  

```graphql
query GetUsersWithPosts($first: Int!) {
  users(first: $first) @stream(initialCount: 2, label: "users") {
    edges {
      node {
        id
        name
        # Stream user's posts independently
        posts(first: 5) @stream(initialCount: 2, label: "userPosts") {
          edges {
            node {
              id
              title
            }
          }
        }
      }
    }
  }
}
```

## Response Format

### Initial Response

```json
{
  "data": {
    "posts": {
      "pageInfo": {
        "hasNextPage": true,
        "hasPreviousPage": false,
        "startCursor": "Y3Vyc29yMQ==",
        "endCursor": "Y3Vyc29yMg=="
      },
      "edges": [
        {
          "cursor": "Y3Vyc29yMQ==",
          "node": {"id": "1", "title": "First Post"}
        },
        {
          "cursor": "Y3Vyc29yMg==", 
          "node": {"id": "2", "title": "Second Post"}
        }
      ]
    }
  },
  "pending": [
    {"label": "posts", "path": ["posts"]}
  ]
}
```

### Incremental Response

```json
{
  "incremental": [{
    "label": "posts",
    "path": ["posts"],
    "items": [
      {
        "cursor": "Y3Vyc29yMw==",
        "node": {"id": "3", "title": "Third Post"}
      },
      {
        "cursor": "Y3Vyc29yNA==",
        "node": {"id": "4", "title": "Fourth Post"}  
      }
    ]
  }]
}
```

### Updated PageInfo

```json
{
  "incremental": [{
    "label": "posts",  
    "path": ["posts", "pageInfo"],
    "data": {
      "endCursor": "Y3Vyc29yNA==",
      "hasNextPage": true
    }
  }]
}
```

## Advanced Features

### Cursor Management

The system automatically:
- Maintains cursor ordering during streaming
- Updates `pageInfo` as new edges arrive
- Ensures cursor consistency across batches

```elixir
# Custom cursor generation
defmodule MyApp.Resolvers do
  def list_posts(args) do
    # Ensure stable cursor generation for streaming
    posts = 
      Post
      |> order_by([p], [desc: p.inserted_at, asc: p.id])  # Stable ordering
      |> Connection.from_query(&Repo.all/1, args)
    
    {:ok, posts}
  end
end
```

### Pagination Direction Support

#### Forward Pagination with Streaming

```graphql
query GetMorePosts($first: Int!, $after: String) {
  posts(first: $first, after: $after) @stream(initialCount: 5) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        title
      }
    }
  }
}
```

#### Backward Pagination with Streaming

```graphql
query GetPreviousPosts($last: Int!, $before: String) {
  posts(last: $last, before: $before) @stream(initialCount: 5) {
    pageInfo {
      hasPreviousPage
      startCursor
    }
    edges {
      cursor  
      node {
        id
        title
      }
    }
  }
}
```

### Conditional Streaming

```graphql
query GetPosts($first: Int!, $shouldStream: Boolean!) {
  posts(first: $first) @stream(if: $shouldStream, initialCount: 3) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      cursor
      node {
        id
        title
        publishedAt
      }
    }
  }
}
```

## Client Integration

### JavaScript/React Example

```javascript
import { useLazyQuery } from '@apollo/client';

function PostList() {
  const [loadPosts, { data, loading }] = useLazyQuery(GET_POSTS_QUERY, {
    fetchPolicy: 'cache-and-network',
    notifyOnNetworkStatusChange: true
  });

  const [posts, setPosts] = useState([]);
  const [pageInfo, setPageInfo] = useState({});

  useEffect(() => {
    if (data?.posts) {
      // Initial data
      if (data.posts.edges) {
        setPosts(data.posts.edges);
        setPageInfo(data.posts.pageInfo);
      }
      
      // Incremental data  
      if (data.incremental) {
        data.incremental.forEach(increment => {
          if (increment.label === 'posts' && increment.items) {
            setPosts(prev => [...prev, ...increment.items]);
          }
          if (increment.path?.includes('pageInfo')) {
            setPageInfo(prev => ({ ...prev, ...increment.data }));
          }
        });
      }
    }
  }, [data]);

  const loadMore = () => {
    if (pageInfo.hasNextPage) {
      loadPosts({
        variables: { 
          first: 10, 
          after: pageInfo.endCursor,
          shouldStream: true
        }
      });
    }
  };

  return (
    <div>
      {posts.map(edge => (
        <PostCard key={edge.node.id} post={edge.node} />
      ))}
      
      {pageInfo.hasNextPage && (
        <button onClick={loadMore} disabled={loading}>
          {loading ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

### Relay Modern Example

```javascript
import { graphql, usePaginationFragment } from 'react-relay';

const PostListPaginationFragment = graphql`
  fragment PostList_posts on Query
  @refetchable(queryName: "PostListPaginationQuery")
  @argumentDefinitions(
    first: { type: "Int", defaultValue: 10 }
    after: { type: "String" }
    shouldStream: { type: "Boolean", defaultValue: true }
  ) {
    posts(first: $first, after: $after)
    @stream(if: $shouldStream, initialCount: 3, label: "posts")
    @connection(key: "PostList_posts") {
      pageInfo {
        hasNextPage
        endCursor
      }
      edges {
        cursor
        node {
          id
          title
          publishedAt
        }
      }
    }
  }
`;

function PostList({ query }) {
  const {
    data,
    loadNext,
    hasNext,
    isLoadingNext
  } = usePaginationFragment(PostListPaginationFragment, query);

  return (
    <div>
      {data.posts.edges.map(edge => (
        <PostCard key={edge.node.id} post={edge.node} />
      ))}
      
      {hasNext && (
        <button 
          onClick={() => loadNext(10)}
          disabled={isLoadingNext}
        >
          {isLoadingNext ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

## Performance Optimization

### Batch Size Configuration

```elixir
# Configure optimal batch sizes per connection type
connection field :posts, node_type: :post do
  meta incremental: [
    stream_batch_size: 10,      # Good for small post objects
    defer_fragments: true       # Allow fragment deferral  
  ]
  
  resolve &Resolvers.list_posts/2
end

connection field :large_items, node_type: :large_item do
  meta incremental: [
    stream_batch_size: 3,       # Smaller batches for large objects
    defer_fragments: true
  ]
  
  resolve &Resolvers.list_large_items/2  
end
```

### Dataloader Optimization

```elixir
# Maintain efficient batching across streaming
defmodule MyApp.Resolvers do
  def list_posts(args) do
    # Dataloader continues to batch efficiently  
    posts = Connection.from_query(Post, &Repo.all/1, args)
    {:ok, posts}
  end

  def post_author(post, _, %{context: %{loader: loader}}) do
    # Batched loading works across streaming boundaries
    loader
    |> Dataloader.load(User, :user, post.author_id)
    |> on_load(fn loader ->
      {:ok, Dataloader.get(loader, User, :user, post.author_id)}
    end)
  end
end
```

### Memory Management  

```elixir
# Configure connection limits
config :absinthe_relay, :incremental,
  max_connection_size: 1000,
  stream_buffer_size: 100,
  cleanup_interval: 60_000
```

## Error Handling

### Partial Failure Recovery

```json
{
  "incremental": [{
    "label": "posts",
    "path": ["posts"],
    "items": [
      {"cursor": "Y3Vyc29yMw==", "node": {"id": "3", "title": "Post 3"}},
      null  // Failed to load
    ],
    "errors": [{
      "message": "Post not found",
      "path": ["posts", "edges", 1, "node"]
    }]
  }]
}
```

### Connection State Recovery

The system ensures:
- Cursor consistency despite errors
- Proper `pageInfo` updates
- Graceful degradation on failures

## Testing

### Unit Tests

```elixir
defmodule MyApp.Schema.IncrementalConnectionTest do
  use ExUnit.Case, async: true
  use Absinthe.Test, schema: MyApp.Schema

  test "streams connection edges incrementally" do
    query = """
    query GetPosts($first: Int!) {
      posts(first: $first) @stream(initialCount: 2, label: "posts") {
        pageInfo {
          hasNextPage
          endCursor
        }
        edges {
          cursor
          node {
            id
            title
          }
        }
      }
    }
    """
    
    result = run_streaming_query(query, %{"first" => 10})
    
    # Initial response has 2 edges
    assert length(result.initial.data["posts"]["edges"]) == 2
    assert result.initial.data["posts"]["pageInfo"]["hasNextPage"] == true
    
    # Incremental responses have remaining edges
    streamed_items = collect_streamed_items(result.incremental, "posts")
    assert length(streamed_items) == 8
    
    # Cursors are properly ordered
    all_cursors = extract_cursors(result)
    assert cursors_ordered?(all_cursors)
  end
  
  test "handles pagination with streaming" do
    # Test forward/backward pagination
    # Test cursor consistency
    # Test pageInfo updates
  end
end
```

### Integration Tests

```elixir
defmodule MyApp.IncrementalConnectionIntegrationTest do
  use ExUnit.Case, async: false
  use Phoenix.ChannelTest
  
  test "WebSocket connection streaming" do
    # Test complete WebSocket flow
    # Test connection lifecycle
    # Test error recovery
  end
  
  test "SSE connection streaming" do  
    # Test Server-Sent Events
    # Test client reconnection
    # Test partial failures
  end
end
```

## Monitoring

### Connection Metrics

```elixir
:telemetry.attach_many(
  "relay-incremental-metrics",
  [
    [:absinthe_relay, :incremental, :connection, :start],
    [:absinthe_relay, :incremental, :connection, :stream],
    [:absinthe_relay, :incremental, :connection, :complete]
  ],
  &MyApp.Telemetry.handle_relay_event/4,
  %{}
)

def handle_relay_event([:absinthe_relay, :incremental, :connection, :stream], measurements, metadata, _config) do
  # Track streaming metrics
  :telemetry.execute(
    [:myapp, :relay, :connection_stream],
    %{
      batch_size: measurements.batch_size,
      total_edges: measurements.total_edges,
      cursor_position: measurements.cursor_position
    },
    metadata
  )
end
```

### Performance Tracking

Key metrics to monitor:
- Connection streaming latency
- Cursor consistency validation
- Edge batch sizes and timing
- Memory usage per connection
- Error rates per connection type

## Troubleshooting

### Common Issues

1. **Cursor ordering problems**
   - Ensure stable sorting in resolvers  
   - Check cursor generation consistency
   - Verify database ordering guarantees

2. **PageInfo inconsistencies**
   - Monitor pageInfo updates during streaming
   - Validate hasNextPage/hasPreviousPage logic
   - Check endCursor/startCursor updates

3. **Performance degradation**
   - Profile batch size effectiveness
   - Monitor dataloader batching efficiency  
   - Check memory usage patterns

### Debug Utilities

```elixir
# Debug cursor consistency
defmodule MyApp.Debug.CursorValidator do
  def validate_stream_cursors(streaming_result) do
    all_cursors = extract_all_cursors(streaming_result)
    
    case validate_ordering(all_cursors) do
      :ok -> :ok
      {:error, reason} -> 
        Logger.error("Cursor ordering violation: #{reason}")
        {:error, reason}
    end
  end
end
```

## Examples

See [examples/](examples/) for:
- Complete Relay Modern integration
- Real-time comment streaming
- Infinite scroll implementation
- Performance benchmarks

## Contributing

Priority areas for contribution:
- Relay Modern compatibility testing
- Performance optimization
- Cursor consistency edge cases  
- Documentation improvements