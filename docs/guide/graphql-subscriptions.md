# GraphQL Subscriptions

GraphQL subscriptions provide real-time updates through WebSocket connections. api.zig supports both the `graphql-ws` and legacy `subscriptions-transport-ws` protocols.

## Overview

Subscriptions enable clients to receive push notifications when data changes, perfect for:

- Live notifications
- Real-time chat
- Live dashboards
- Collaborative editing
- Gaming events

## Basic Setup

### Schema Definition

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    var schema = api.GraphQLSchema.init(allocator);
    defer schema.deinit();

    // Define subscription type
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
                .description = "Subscribe to user status changes",
            },
            .{
                .name = "orderUpdated",
                .type_name = "Order",
                .args = &.{
                    .{ .name = "orderId", .type_name = "ID", .is_non_null = true },
                },
                .description = "Subscribe to order updates",
            },
        },
    });

    // Enable GraphQL with subscriptions
    try app.enableGraphQL(&schema, .{
        .enable_subscriptions = true,
        .subscription_config = .{
            .protocol = .graphql_ws,
            .keep_alive = true,
            .keep_alive_interval_ms = 30000,
        },
    });

    try app.run(.{ .port = 8000 });
}
```

## Subscription Configuration

### SubscriptionConfig

```zig
pub const SubscriptionConfig = struct {
    /// WebSocket protocol to use
    protocol: SubscriptionProtocol = .graphql_ws,
    
    /// Enable keep-alive pings
    keep_alive: bool = true,
    
    /// Keep-alive interval in milliseconds
    keep_alive_interval_ms: u32 = 30000,
    
    /// Connection timeout in milliseconds
    connection_timeout_ms: u32 = 30000,
    
    /// Maximum retry attempts
    max_retry_attempts: u32 = 5,
    
    /// Retry delay in milliseconds
    retry_delay_ms: u32 = 1000,
    
    /// Lazy connection (connect on first subscription)
    lazy: bool = true,
    
    /// Maximum concurrent subscriptions per connection
    max_subscriptions: u32 = 100,
    
    /// Enable connection acknowledgment timeout
    ack_timeout_ms: u32 = 10000,
};
```

### Subscription Protocols

```zig
pub const SubscriptionProtocol = enum {
    /// Modern graphql-ws protocol
    graphql_ws,
    
    /// Legacy subscriptions-transport-ws protocol
    subscriptions_transport_ws,
    
    /// Server-Sent Events (SSE)
    sse,
};
```

## WebSocket Endpoint

### Default Setup

```zig
try app.enableGraphQL(&schema, .{
    .path = "/graphql",
    .enable_subscriptions = true,
    // WebSocket endpoint: ws://localhost:8000/graphql/ws
});
```

### Custom WebSocket Path

```zig
try app.enableGraphQL(&schema, .{
    .path = "/api/graphql",
    .subscription_path = "/api/graphql/subscriptions",
    .enable_subscriptions = true,
});
```

## UI Configuration

### GraphiQL with Subscriptions

```zig
try app.enableGraphQL(&schema, .{
    .graphiql_path = "/graphql/graphiql",
    .ui_config = .{
        .endpoint = "/graphql",
        .subscription_endpoint = "ws://localhost:8000/graphql/ws",
    },
});
```

### Playground with Subscriptions

```zig
try app.enableGraphQL(&schema, .{
    .playground_path = "/graphql/playground",
    .ui_config = .{
        .provider = .playground,
        .endpoint = "/graphql",
        .subscription_endpoint = "ws://localhost:8000/graphql/ws",
    },
});
```

## Client Usage

### JavaScript Client (graphql-ws)

```javascript
import { createClient } from 'graphql-ws';

const client = createClient({
  url: 'ws://localhost:8000/graphql/ws',
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
          sender {
            name
          }
        }
      }
    `,
    variables: { channelId: '123' },
  },
  {
    next: (data) => console.log('Message:', data),
    error: (err) => console.error('Error:', err),
    complete: () => console.log('Subscription complete'),
  }
);

// Later: unsubscribe
unsubscribe();
```

### Apollo Client

```javascript
import { ApolloClient, InMemoryCache, split, HttpLink } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { createClient } from 'graphql-ws';
import { getMainDefinition } from '@apollo/client/utilities';

const httpLink = new HttpLink({
  uri: 'http://localhost:8000/graphql',
});

const wsLink = new GraphQLWsLink(
  createClient({
    url: 'ws://localhost:8000/graphql/ws',
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

## Common Patterns

### Chat Application

```zig
// Schema
try schema.addObjectType(.{
    .name = "Message",
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "text", .type_name = "String", .is_non_null = true },
        .{ .name = "sender", .type_name = "User", .is_non_null = true },
        .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
        .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
    },
});

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
        },
        .{
            .name = "userTyping",
            .type_name = "TypingIndicator",
            .args = &.{
                .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
            },
        },
    },
});
```

### Live Dashboard

```zig
try schema.setSubscriptionType(.{
    .name = "Subscription",
    .fields = &.{
        .{
            .name = "metricsUpdated",
            .type_name = "Metrics",
            .is_non_null = true,
            .description = "Real-time metrics updates",
        },
        .{
            .name = "alertTriggered",
            .type_name = "Alert",
            .is_non_null = true,
            .description = "New alert notifications",
        },
        .{
            .name = "serverStatus",
            .type_name = "ServerStatus",
            .is_non_null = true,
            .args = &.{
                .{ .name = "serverId", .type_name = "ID" },
            },
        },
    },
});
```

### Collaborative Editing

```zig
try schema.setSubscriptionType(.{
    .name = "Subscription",
    .fields = &.{
        .{
            .name = "documentChanged",
            .type_name = "DocumentChange",
            .is_non_null = true,
            .args = &.{
                .{ .name = "documentId", .type_name = "ID", .is_non_null = true },
            },
        },
        .{
            .name = "cursorMoved",
            .type_name = "CursorPosition",
            .args = &.{
                .{ .name = "documentId", .type_name = "ID", .is_non_null = true },
            },
        },
        .{
            .name = "userJoined",
            .type_name = "User",
            .args = &.{
                .{ .name = "documentId", .type_name = "ID", .is_non_null = true },
            },
        },
    },
});
```

## Authentication

### Connection-Level Auth

```zig
try app.enableGraphQL(&schema, .{
    .enable_subscriptions = true,
    .subscription_config = .{
        .on_connect = struct {
            fn authenticate(params: anytype) !bool {
                const token = params.get("authToken") orelse return false;
                return validateToken(token);
            }
        }.authenticate,
    },
});
```

### Client Connection Params

```javascript
const client = createClient({
  url: 'ws://localhost:8000/graphql/ws',
  connectionParams: async () => ({
    authToken: await getAuthToken(),
    userId: getCurrentUserId(),
  }),
});
```

## Error Handling

### Subscription Errors

```javascript
client.subscribe(
  { query: subscriptionQuery },
  {
    next: (data) => handleData(data),
    error: (errors) => {
      if (errors instanceof CloseEvent) {
        // Connection closed
        console.log('Connection closed:', errors.code, errors.reason);
      } else {
        // GraphQL errors
        console.error('Subscription error:', errors);
      }
    },
    complete: () => console.log('Subscription completed'),
  }
);
```

### Reconnection

```javascript
const client = createClient({
  url: 'ws://localhost:8000/graphql/ws',
  retryAttempts: 5,
  retryWait: (retries) => {
    // Exponential backoff
    return new Promise((resolve) =>
      setTimeout(resolve, Math.min(1000 * 2 ** retries, 30000))
    );
  },
  on: {
    connected: () => console.log('Connected'),
    closed: (event) => console.log('Closed:', event),
    error: (error) => console.error('Error:', error),
  },
});
```

## Best Practices

### 1. Use Specific Subscriptions

```graphql
# Good: Subscribe to specific resources
subscription OrderUpdates($orderId: ID!) {
  orderUpdated(orderId: $orderId) {
    status
    updatedAt
  }
}

# Avoid: Broad subscriptions without filters
subscription AllOrderUpdates {
  allOrders {
    ...everything
  }
}
```

### 2. Handle Disconnections

```javascript
const client = createClient({
  url: 'ws://localhost:8000/graphql/ws',
  keepAlive: 30000, // 30 seconds
  on: {
    ping: () => console.log('Ping'),
    pong: () => console.log('Pong'),
  },
});
```

### 3. Limit Concurrent Subscriptions

```zig
try app.enableGraphQL(&schema, .{
    .subscription_config = .{
        .max_subscriptions = 10, // Per connection
    },
});
```

## See Also

- [GraphQL Guide](/guide/graphql) - Getting started
- [WebSocket Module](/api/websocket) - WebSocket API
- [Real-time Updates](/guide/real-time) - Other real-time options
