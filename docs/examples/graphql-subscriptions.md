# GraphQL Subscriptions Example

This example demonstrates real-time GraphQL subscriptions with api.zig, enabling push notifications for live data updates.

## Full Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "GraphQL Subscriptions",
        .version = "1.0.0",
    });
    defer app.deinit();

    var schema = api.graphql.Schema.init(allocator);
    defer schema.deinit();

    // Message type
    try schema.addObjectType(.{
        .name = "Message",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "text", .type_name = "String", .is_non_null = true },
            .{ .name = "sender", .type_name = "String", .is_non_null = true },
            .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
            .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
        },
    });

    // User status type
    try schema.addObjectType(.{
        .name = "UserStatus",
        .fields = &.{
            .{ .name = "userId", .type_name = "ID", .is_non_null = true },
            .{ .name = "username", .type_name = "String", .is_non_null = true },
            .{ .name = "online", .type_name = "Boolean", .is_non_null = true },
            .{ .name = "lastSeen", .type_name = "DateTime" },
        },
    });

    // Query type
    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "messages", .type_name = "Message", .is_list = true, .args = &.{
                .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
                .{ .name = "limit", .type_name = "Int", .default_value = "50" },
            }},
            .{ .name = "onlineUsers", .type_name = "UserStatus", .is_list = true },
        },
    });

    // Mutation type
    try schema.setMutationType(.{
        .name = "Mutation",
        .fields = &.{
            .{ .name = "sendMessage", .type_name = "Message", .args = &.{
                .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
                .{ .name = "text", .type_name = "String", .is_non_null = true },
            }},
            .{ .name = "setStatus", .type_name = "UserStatus", .args = &.{
                .{ .name = "online", .type_name = "Boolean", .is_non_null = true },
            }},
        },
    });

    // Subscription type
    try schema.setSubscriptionType(.{
        .name = "Subscription",
        .fields = &.{
            .{
                .name = "messageAdded",
                .type_name = "Message",
                .is_non_null = true,
                .args = &.{
                    .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
                },
                .description = "Subscribe to new messages in a channel",
            },
            .{
                .name = "userStatusChanged",
                .type_name = "UserStatus",
                .is_non_null = true,
                .description = "Subscribe to user online/offline status changes",
            },
            .{
                .name = "typing",
                .type_name = "String",
                .args = &.{
                    .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
                },
                .description = "Subscribe to typing indicators",
            },
        },
    });

    // Enable GraphQL with subscriptions
    try app.enableGraphQL(&schema, .{
        .path = "/graphql",
        .graphiql_path = "/graphql/graphiql",
        .playground_path = "/graphql/playground",
        .enable_subscriptions = true,
        .subscription_config = .{
            .protocol = .graphql_ws,
            .keep_alive = true,
            .keep_alive_interval_ms = 30000,
            .connection_timeout_ms = 30000,
        },
        .ui_config = .{
            .theme = .dark,
            .title = "Chat API",
            .subscription_endpoint = "ws://localhost:8080/graphql/ws",
        },
    });

    try app.run(.{ .port = 8080 });
}
```

## Schema Definition

### Subscription Type

```zig
try schema.setSubscriptionType(.{
    .name = "Subscription",
    .fields = &.{
        // Channel-specific subscription
        .{
            .name = "messageAdded",
            .type_name = "Message",
            .is_non_null = true,
            .args = &.{
                .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
            },
            .description = "New messages in a channel",
        },
        // Global subscription
        .{
            .name = "userStatusChanged",
            .type_name = "UserStatus",
            .is_non_null = true,
            .description = "User online/offline changes",
        },
        // Optional filter
        .{
            .name = "orderUpdated",
            .type_name = "Order",
            .args = &.{
                .{ .name = "orderId", .type_name = "ID" },  // Optional filter
            },
            .description = "Order status updates",
        },
    },
});
```

## Configuration

### Subscription Config

```zig
try app.enableGraphQL(&schema, .{
    .enable_subscriptions = true,
    .subscription_config = .{
        // Protocol selection
        .protocol = .graphql_ws,  // Modern protocol
        
        // Keep-alive settings
        .keep_alive = true,
        .keep_alive_interval_ms = 30000,
        
        // Connection settings
        .connection_timeout_ms = 30000,
        .max_retry_attempts = 5,
        .retry_delay_ms = 1000,
        
        // Limits
        .max_subscriptions = 100,  // Per connection
        
        // Lazy connection
        .lazy = true,  // Connect on first subscription
    },
});
```

### Protocols

| Protocol | Description |
|----------|-------------|
| `graphql_ws` | Modern graphql-ws protocol (recommended) |
| `subscriptions_transport_ws` | Legacy Apollo protocol |
| `sse` | Server-Sent Events |

## Client Integration

### JavaScript (graphql-ws)

```javascript
import { createClient } from 'graphql-ws';

const client = createClient({
  url: 'ws://localhost:8080/graphql/ws',
  connectionParams: {
    authToken: 'your-token',
  },
});

// Subscribe to messages
const unsubscribe = client.subscribe(
  {
    query: `
      subscription MessageAdded($channelId: ID!) {
        messageAdded(channelId: $channelId) {
          id
          text
          sender
          createdAt
        }
      }
    `,
    variables: { channelId: 'general' },
  },
  {
    next: (data) => {
      console.log('New message:', data.data.messageAdded);
    },
    error: (err) => console.error(err),
    complete: () => console.log('Subscription complete'),
  }
);

// Unsubscribe when done
unsubscribe();
```

### Apollo Client

```javascript
import { ApolloClient, InMemoryCache, split, HttpLink } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { createClient } from 'graphql-ws';
import { getMainDefinition } from '@apollo/client/utilities';

const httpLink = new HttpLink({
  uri: 'http://localhost:8080/graphql',
});

const wsLink = new GraphQLWsLink(
  createClient({
    url: 'ws://localhost:8080/graphql/ws',
  })
);

const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query);
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    );
  },
  wsLink,
  httpLink
);

const client = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache(),
});
```

### React Hook

```jsx
import { useSubscription, gql } from '@apollo/client';

const MESSAGE_SUBSCRIPTION = gql`
  subscription MessageAdded($channelId: ID!) {
    messageAdded(channelId: $channelId) {
      id
      text
      sender
      createdAt
    }
  }
`;

function ChatMessages({ channelId }) {
  const { data, loading, error } = useSubscription(MESSAGE_SUBSCRIPTION, {
    variables: { channelId },
  });

  if (loading) return <p>Connecting...</p>;
  if (error) return <p>Error: {error.message}</p>;

  return (
    <div>
      <strong>{data.messageAdded.sender}:</strong>
      <span>{data.messageAdded.text}</span>
    </div>
  );
}
```

## Use Cases

### Real-time Chat

```graphql
subscription ChatMessages($channelId: ID!) {
  messageAdded(channelId: $channelId) {
    id
    text
    sender
    createdAt
  }
}
```

### Live Notifications

```graphql
subscription UserNotifications {
  notificationReceived {
    id
    type
    title
    message
    read
    createdAt
  }
}
```

### Live Dashboard

```graphql
subscription DashboardMetrics {
  metricsUpdated {
    cpu
    memory
    requests
    errors
    timestamp
  }
}
```

### Order Tracking

```graphql
subscription OrderStatus($orderId: ID!) {
  orderUpdated(orderId: $orderId) {
    id
    status
    location
    estimatedDelivery
    updatedAt
  }
}
```

### Collaborative Editing

```graphql
subscription DocumentChanges($documentId: ID!) {
  documentChanged(documentId: $documentId) {
    userId
    operation
    position
    content
    timestamp
  }
}
```

## Testing Subscriptions

### Using GraphiQL

1. Open http://localhost:8080/graphql/graphiql
2. Enter subscription query:

```graphql
subscription {
  messageAdded(channelId: "general") {
    id
    text
    sender
  }
}
```

3. Click "Play" to start subscription
4. Send a message via mutation in another tab
5. See real-time updates in the first tab

### Using Playground

1. Open http://localhost:8080/graphql/playground
2. Enter subscription in one tab
3. Enter mutation in another tab
4. Execute both to see real-time flow

## Error Handling

```javascript
const client = createClient({
  url: 'ws://localhost:8080/graphql/ws',
  retryAttempts: 5,
  retryWait: (retries) => {
    return new Promise((resolve) =>
      setTimeout(resolve, Math.min(1000 * 2 ** retries, 30000))
    );
  },
  on: {
    connected: () => console.log('Connected'),
    closed: (event) => {
      if (event.wasClean) {
        console.log('Connection closed cleanly');
      } else {
        console.error('Connection lost');
      }
    },
    error: (error) => console.error('WebSocket error:', error),
  },
});
```

## Best Practices

1. **Use specific subscriptions** - Filter by ID when possible
2. **Handle disconnections** - Implement retry logic
3. **Clean up subscriptions** - Unsubscribe when components unmount
4. **Limit concurrent subscriptions** - Don't overload the connection
5. **Use authentication** - Pass tokens in connectionParams

## See Also

- [Basic GraphQL](/examples/graphql-basic) - Getting started
- [GraphQL Guide](/guide/graphql) - Complete guide
- [WebSocket](/api/websocket) - WebSocket API
