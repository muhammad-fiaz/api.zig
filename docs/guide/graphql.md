# GraphQL Guide

This guide covers GraphQL integration in api.zig, providing a complete toolkit for building GraphQL APIs with multiple UI providers, production-ready features, and extensive customization options.

## Why GraphQL in api.zig?

api.zig's GraphQL support is designed to be:

- **Developer-Friendly**: Multiple UI options (GraphiQL, Playground, Apollo Sandbox, Altair, Voyager)
- **Production-Ready**: Built-in caching, complexity analysis, depth limiting, and error masking
- **Type-Safe**: Leverages Zig's compile-time type safety
- **High-Performance**: Zero-allocation query parsing where possible
- **Federation-Ready**: Apollo Federation v1/v2 support for microservices

## Getting Started

### Basic Setup

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My GraphQL API",
    });
    defer app.deinit();

    // Create and configure schema
    var schema = api.GraphQLSchema.init(allocator);
    defer schema.deinit();

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "hello", .type_name = "String", .is_non_null = true },
        },
    });

    // Enable GraphQL with default settings
    try app.enableGraphQL(&schema, .{});

    try app.run(.{ .port = 8000 });
}
```

### Accessing GraphQL

After setup, your API provides:

| Endpoint | Description |
|----------|-------------|
| `POST /graphql` | GraphQL query endpoint |
| `GET /graphql/graphiql` | GraphiQL IDE |
| `GET /graphql/playground` | GraphQL Playground |

## Building a Schema

### Query Type

The Query type defines read operations:

```zig
try schema.setQueryType(.{
    .name = "Query",
    .description = "Root query type",
    .fields = &.{
        .{
            .name = "users",
            .type_name = "User",
            .is_list = true,
            .is_non_null = true,
            .description = "Fetch all users",
        },
        .{
            .name = "user",
            .type_name = "User",
            .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            },
            .description = "Fetch a single user by ID",
        },
        .{
            .name = "searchUsers",
            .type_name = "User",
            .is_list = true,
            .args = &.{
                .{ .name = "query", .type_name = "String", .is_non_null = true },
                .{ .name = "limit", .type_name = "Int", .default_value = "10" },
            },
        },
    },
});
```

### Mutation Type

The Mutation type defines write operations:

```zig
try schema.setMutationType(.{
    .name = "Mutation",
    .fields = &.{
        .{
            .name = "createUser",
            .type_name = "User",
            .args = &.{
                .{ .name = "input", .type_name = "CreateUserInput", .is_non_null = true },
            },
        },
        .{
            .name = "updateUser",
            .type_name = "User",
            .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
                .{ .name = "input", .type_name = "UpdateUserInput", .is_non_null = true },
            },
        },
        .{
            .name = "deleteUser",
            .type_name = "Boolean",
            .is_non_null = true,
            .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            },
        },
    },
});
```

### Subscription Type

The Subscription type defines real-time events:

```zig
try schema.setSubscriptionType(.{
    .name = "Subscription",
    .fields = &.{
        .{
            .name = "userCreated",
            .type_name = "User",
            .is_non_null = true,
        },
        .{
            .name = "messageAdded",
            .type_name = "Message",
            .args = &.{
                .{ .name = "channelId", .type_name = "ID", .is_non_null = true },
            },
        },
    },
});
```

### Object Types

```zig
try schema.addObjectType(.{
    .name = "User",
    .description = "A user in the system",
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "email", .type_name = "Email", .is_non_null = true },
        .{ .name = "name", .type_name = "String", .is_non_null = true },
        .{ .name = "avatar", .type_name = "URL" },
        .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
        .{ .name = "posts", .type_name = "Post", .is_list = true },
        .{ .name = "role", .type_name = "UserRole", .is_non_null = true },
    },
});
```

### Input Types

```zig
try schema.addInputType("CreateUserInput", &.{
    .{ .name = "email", .type_name = "Email", .is_non_null = true },
    .{ .name = "name", .type_name = "String", .is_non_null = true },
    .{ .name = "password", .type_name = "String", .is_non_null = true },
    .{ .name = "role", .type_name = "UserRole", .default_value = "USER" },
}, "Input for creating a new user");

try schema.addInputType("UpdateUserInput", &.{
    .{ .name = "name", .type_name = "String" },
    .{ .name = "avatar", .type_name = "URL" },
    .{ .name = "role", .type_name = "UserRole" },
}, "Input for updating an existing user");
```

### Enum Types

```zig
try schema.addEnumType("UserRole", &.{
    .{ .name = "ADMIN", .description = "Full system access" },
    .{ .name = "MODERATOR", .description = "Content moderation access" },
    .{ .name = "USER", .description = "Standard user" },
    .{ .name = "GUEST", .description = "Read-only access" },
}, "User permission roles");
```

### Interface Types

```zig
try schema.addInterfaceType("Node", &.{
    .{ .name = "id", .type_name = "ID", .is_non_null = true },
}, "Relay-compatible Node interface");

try schema.addInterfaceType("Timestamped", &.{
    .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
    .{ .name = "updatedAt", .type_name = "DateTime" },
}, "Objects with timestamps");
```

### Union Types

```zig
try schema.addUnionType("SearchResult", &.{
    "User", "Post", "Comment", "Tag",
}, "Search result that can be different types");
```

## UI Configuration

### Choosing a UI Provider

api.zig supports 5 different GraphQL UI providers:

| Provider | Best For |
|----------|----------|
| **GraphiQL** | Most developers, modern interface |
| **Playground** | Rich feature set, tabs support |
| **Apollo Sandbox** | Apollo ecosystem users |
| **Altair** | Advanced features, file uploads |
| **Voyager** | Schema visualization |

### Enable All UIs

```zig
try app.enableAllGraphQLUIs(&schema, .{
    .base_path = "/graphql",
    .theme = .dark,
});

// Creates:
// /graphql          - GraphQL endpoint
// /graphql/graphiql - GraphiQL
// /graphql/playground - Playground
// /graphql/sandbox  - Apollo Sandbox
// /graphql/altair   - Altair
// /graphql/voyager  - Voyager
```

### Customizing UI

```zig
try app.enableGraphQL(&schema, .{
    .path = "/graphql",
    .ui_config = .{
        .provider = .graphiql,
        .theme = .dark,
        .title = "My API Explorer",
        .logo_url = "/logo.png",
        .default_query =
            \\query {
            \\  users {
            \\    id
            \\    name
            \\  }
            \\}
        ,
        .default_headers = &.{
            .{ .key = "Authorization", .value = "Bearer <token>" },
        },
        .show_docs = true,
        .show_history = true,
        .enable_persistence = true,
        .code_completion = true,
        .editor_font_size = 14,
        .custom_css = 
            \\.graphiql-container { font-family: 'Fira Code'; }
        ,
    },
});
```

## Production Configuration

### Enable All Production Features

```zig
try app.enableGraphQL(&schema, .{
    .schema = &schema,
    .path = "/graphql",
    
    // Security
    .enable_introspection = false,  // Disable in production
    .mask_errors = true,
    .enable_persisted_queries = true,
    .persisted_queries_only = true,  // Block arbitrary queries
    
    // Performance
    .enable_caching = true,
    .cache_ttl_ms = 60000,
    .enable_batching = true,
    .max_batch_size = 10,
    
    // Limits
    .max_depth = 10,
    .max_complexity = 500,
    
    // Monitoring
    .enable_tracing = true,
});
```

### Middleware Stack

```zig
// Add GraphQL-specific middleware
const gql_middleware = api.graphqlMiddleware(.{
    .enable_complexity_analysis = true,
    .max_complexity = 500,
    .enable_depth_limiting = true,
    .max_depth = 10,
    .enable_introspection = false,
    .paths = &.{"/graphql"},
});

const cors = api.graphqlCors(.{
    .allowed_origins = &.{"https://myapp.com"},
    .allowed_methods = &.{"GET", "POST", "OPTIONS"},
    .allow_credentials = true,
});

const rate_limit = api.graphqlRateLimit(.{
    .query_limit = 1000,
    .mutation_limit = 100,
    .window_seconds = 3600,
});

try app.use(cors.handle);
try app.use(rate_limit.handle);
try app.use(gql_middleware.handle);
```

## Complete Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Blog API",
        .version = "2.0.0",
        .description = "A complete blog platform API",
    });
    defer app.deinit();

    var schema = api.GraphQLSchema.init(allocator);
    defer schema.deinit();

    // Types
    try schema.addEnumType("PostStatus", &.{
        .{ .name = "DRAFT" },
        .{ .name = "PUBLISHED" },
        .{ .name = "ARCHIVED" },
    }, null);

    try schema.addObjectType(.{
        .name = "User",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "email", .type_name = "Email", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "posts", .type_name = "Post", .is_list = true },
        },
    });

    try schema.addObjectType(.{
        .name = "Post",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "title", .type_name = "String", .is_non_null = true },
            .{ .name = "content", .type_name = "String" },
            .{ .name = "status", .type_name = "PostStatus", .is_non_null = true },
            .{ .name = "author", .type_name = "User", .is_non_null = true },
            .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
        },
    });

    // Query
    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "posts", .type_name = "Post", .is_list = true },
            .{ .name = "post", .type_name = "Post", .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            }},
            .{ .name = "users", .type_name = "User", .is_list = true },
        },
    });

    // Mutation
    try schema.setMutationType(.{
        .name = "Mutation",
        .fields = &.{
            .{ .name = "createPost", .type_name = "Post", .args = &.{
                .{ .name = "title", .type_name = "String", .is_non_null = true },
                .{ .name = "content", .type_name = "String" },
            }},
            .{ .name = "publishPost", .type_name = "Post", .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            }},
        },
    });

    // Enable GraphQL
    try app.enableGraphQL(&schema, .{
        .path = "/graphql",
        .playground_path = "/graphql/playground",
        .graphiql_path = "/graphql/graphiql",
        .ui_config = .{
            .theme = .dark,
            .title = "Blog API Explorer",
        },
    });

    std.debug.print("Blog API running at http://localhost:8000\n", .{});
    std.debug.print("GraphiQL: http://localhost:8000/graphql/graphiql\n", .{});

    try app.run(.{ .port = 8000 });
}
```

## Next Steps

- [GraphQL Schema Design](/guide/graphql-schema) - Advanced schema patterns
- [GraphQL Subscriptions](/guide/graphql-subscriptions) - Real-time updates
- [GraphQL UI Customization](/guide/graphql-ui) - Theming and branding
- [API Reference](/api/graphql) - Complete API documentation
