# GraphQL Module

The GraphQL module provides comprehensive GraphQL support for the api.zig framework, featuring multiple UI providers (GraphiQL, Playground, Apollo Sandbox, Altair, Voyager), schema definition, query parsing, execution, subscriptions, and production-ready features like persisted queries, caching, and federation support.

## Overview

```zig
const graphql = @import("api").graphql;
```

## Features

- **Multiple UI Providers**: GraphiQL, GraphQL Playground, Apollo Sandbox, Altair, Voyager
- **Schema Definition**: Complete type system with scalars, objects, interfaces, unions, enums
- **Query Execution**: Full query/mutation/subscription support
- **Production Features**: Persisted queries, complexity analysis, depth limiting
- **Federation**: Apollo Federation v1/v2 support for microservices
- **Caching**: Response caching with configurable TTL
- **Tracing**: APM integration with OpenTelemetry, Datadog, etc.
- **Security**: Error masking, introspection control, rate limiting

## Quick Start

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

    // Create schema
    var schema = api.GraphQLSchema.init(allocator);
    defer schema.deinit();

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "hello", .type_name = "String", .is_non_null = true },
        },
    });

    // Enable GraphQL with all UIs
    try app.enableGraphQL(&schema, .{
        .schema = &schema,
        .path = "/graphql",
        .playground_path = "/graphql/playground",
        .graphiql_path = "/graphql/graphiql",
        .apollo_sandbox_path = "/graphql/sandbox",
        .enable_introspection = true,
    });

    try app.run(.{ .port = 8000 });
}
```

## GraphQL Configuration

### GraphQLConfig

Complete configuration for GraphQL endpoints:

```zig
const GraphQLConfig = struct {
    /// GraphQL schema (required)
    schema: *Schema,
    /// GraphQL endpoint path
    path: []const u8 = "/graphql",
    /// Playground path (null to disable)
    playground_path: ?[]const u8 = "/graphql/playground",
    /// GraphiQL path (null to disable)
    graphiql_path: ?[]const u8 = "/graphql/graphiql",
    /// Apollo Sandbox path (null to disable)
    apollo_sandbox_path: ?[]const u8 = null,
    /// Altair path (null to disable)
    altair_path: ?[]const u8 = null,
    /// Voyager path (null to disable)
    voyager_path: ?[]const u8 = null,
    /// Enable playground/UI
    enable_playground: bool = true,
    /// Enable introspection
    enable_introspection: bool = true,
    /// Maximum query depth
    max_depth: u32 = 15,
    /// Maximum query complexity
    max_complexity: u32 = 1000,
    /// Enable query batching
    enable_batching: bool = false,
    /// Maximum batch size
    max_batch_size: u32 = 10,
    /// Enable tracing
    enable_tracing: bool = false,
    /// Enable persisted queries
    enable_persisted_queries: bool = false,
    /// Only allow persisted queries (security feature)
    persisted_queries_only: bool = false,
    /// Mask errors in production
    mask_errors: bool = true,
    /// Enable response caching
    enable_caching: bool = false,
    /// Cache TTL in milliseconds
    cache_ttl_ms: u64 = 60000,
    /// Enable CORS
    enable_cors: bool = true,
    /// Enable subscriptions
    enable_subscriptions: bool = false,
    // ... and more
};
```

## UI Providers

api.zig provides 5 different GraphQL UI providers, similar to Swagger UI for REST APIs.

### GraphiQL

Modern GraphQL IDE with explorer plugin:

```zig
// Simple usage
const html = api.graphiql("/graphql");

// With configuration
const html = api.graphiqlWithConfig(.{
    .provider = .graphiql,
    .theme = .dark,
    .title = "My GraphQL API",
    .endpoint = "/graphql",
    .show_docs = true,
    .show_history = true,
    .enable_persistence = true,
    .code_completion = true,
});
```

### GraphQL Playground

Feature-rich GraphQL IDE:

```zig
const html = api.graphqlPlayground("/graphql");

// With configuration
const html = api.graphqlPlaygroundWithConfig(.{
    .theme = .dark,
    .schema_polling = true,
    .schema_polling_interval_ms = 2000,
});
```

### Apollo Sandbox

Apollo's embeddable GraphQL IDE:

```zig
const html = api.apolloSandbox("/graphql");

// With configuration
const html = api.apolloSandboxWithConfig(.{
    .title = "Apollo Sandbox",
    .credentials = .include,
});
```

### Altair GraphQL Client

Full-featured GraphQL client:

```zig
const html = api.altairGraphQL("/graphql");
```

### GraphQL Voyager

Interactive schema visualization:

```zig
const html = api.graphqlVoyager("/graphql");
```

### Generate UI by Provider

```zig
const html = api.generateGraphQLUI(.{
    .provider = .playground,  // or .graphiql, .apollo_sandbox, .altair, .voyager
    .theme = .dark,
    .title = "My API",
});
```

## UI Configuration

### GraphQLUIConfig

```zig
pub const GraphQLUIConfig = struct {
    /// UI provider to use
    provider: GraphQLUIProvider = .graphiql,
    /// Theme preference (light, dark, system)
    theme: GraphQLUITheme = .dark,
    /// Title shown in the UI
    title: []const u8 = "GraphQL Explorer",
    /// GraphQL endpoint URL
    endpoint: []const u8 = "/graphql",
    /// WebSocket endpoint for subscriptions
    subscription_endpoint: ?[]const u8 = null,
    /// Enable schema polling
    schema_polling: bool = false,
    /// Schema polling interval in milliseconds
    schema_polling_interval_ms: u32 = 2000,
    /// Show documentation explorer
    show_docs: bool = true,
    /// Show history panel
    show_history: bool = true,
    /// Enable query persistence
    enable_persistence: bool = true,
    /// Custom headers to include
    default_headers: []const HeaderPair = &.{},
    /// Initial query to display
    default_query: ?[]const u8 = null,
    /// Enable keyboard shortcuts
    enable_shortcuts: bool = true,
    /// Tab size for editor
    editor_tab_size: u8 = 2,
    /// Font size for editor
    editor_font_size: u8 = 14,
    /// Enable syntax highlighting
    syntax_highlighting: bool = true,
    /// Enable code completion
    code_completion: bool = true,
    /// Custom CSS for styling
    custom_css: ?[]const u8 = null,
    /// Custom JavaScript
    custom_js: ?[]const u8 = null,
    /// Logo URL for branding
    logo_url: ?[]const u8 = null,
    /// Credentials policy
    credentials: CredentialsPolicy = .same_origin,
};
```

## Schema Definition

### Creating a Schema

```zig
var schema = api.GraphQLSchema.init(allocator);
defer schema.deinit();

// Define Query type
try schema.setQueryType(.{
    .name = "Query",
    .description = "Root query type",
    .fields = &.{
        .{
            .name = "users",
            .type_name = "User",
            .is_list = true,
            .description = "Get all users",
        },
        .{
            .name = "user",
            .type_name = "User",
            .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            },
            .description = "Get user by ID",
        },
    },
});

// Define Mutation type
try schema.setMutationType(.{
    .name = "Mutation",
    .fields = &.{
        .{
            .name = "createUser",
            .type_name = "User",
            .args = &.{
                .{ .name = "name", .type_name = "String", .is_non_null = true },
                .{ .name = "email", .type_name = "String", .is_non_null = true },
            },
        },
    },
});

// Define custom object type
try schema.addObjectType(.{
    .name = "User",
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "name", .type_name = "String", .is_non_null = true },
        .{ .name = "email", .type_name = "String" },
        .{ .name = "posts", .type_name = "Post", .is_list = true },
    },
});
```

### Scalar Types

api.zig provides 30+ built-in scalar types:

| Scalar | Description |
|--------|-------------|
| `ID` | Unique identifier |
| `String` | UTF-8 string |
| `Int` | 32-bit integer |
| `Float` | 64-bit float |
| `Boolean` | true/false |
| `DateTime` | ISO 8601 date-time |
| `JSON` | Arbitrary JSON |
| `Date` | ISO 8601 date |
| `Time` | ISO 8601 time |
| `BigInt` | Arbitrary precision integer |
| `Decimal` | Arbitrary precision decimal |
| `UUID` | UUID v4 |
| `Email` | RFC 5322 email |
| `URL` | RFC 3986 URI |
| `IPv4` | IPv4 address |
| `IPv6` | IPv6 address |
| `Phone` | E.164 phone number |
| `Currency` | ISO 4217 currency |
| `Duration` | ISO 8601 duration |
| `Timestamp` | Unix timestamp |
| `Upload` | File upload |
| `Bytes` | Base64 binary |
| `PositiveInt` | Integer > 0 |
| `NonNegativeInt` | Integer >= 0 |

### Enum Types

```zig
try schema.addEnumType("UserRole", &.{
    .{ .name = "ADMIN", .description = "Administrator" },
    .{ .name = "USER", .description = "Regular user" },
    .{ .name = "GUEST", .description = "Guest user", .is_deprecated = true },
}, "User role enumeration");
```

### Input Types

```zig
try schema.addInputType("CreateUserInput", &.{
    .{ .name = "name", .type_name = "String", .is_non_null = true },
    .{ .name = "email", .type_name = "Email", .is_non_null = true },
    .{ .name = "role", .type_name = "UserRole", .default_value = "USER" },
}, "Input for creating a user");
```

### Interface Types

```zig
try schema.addInterfaceType("Node", &.{
    .{ .name = "id", .type_name = "ID", .is_non_null = true },
}, "Relay Node interface");
```

### Union Types

```zig
try schema.addUnionType("SearchResult", &.{
    "User", "Post", "Comment",
}, "Search result union");
```

## Production Features

### Query Complexity Analysis

```zig
const config = api.ComplexityConfig{
    .enabled = true,
    .max_complexity = 1000,
    .default_field_complexity = 1,
    .list_multiplier = 10,
};
```

### Query Depth Limiting

```zig
const config = api.DepthConfig{
    .enabled = true,
    .max_depth = 15,
    .ignore_introspection = true,
};
```

### Persisted Queries

```zig
const config = api.PersistedQueriesConfig{
    .enabled = true,
    .only_persisted = false,  // Set to true for security
    .use_sha256 = true,
};
```

### Response Caching

```zig
const config = api.ResponseCacheConfig{
    .enabled = true,
    .max_size = 1000,
    .default_ttl_ms = 60000,
    .skip_mutations = true,
};
```

### Error Handling

```zig
const config = api.ErrorConfig{
    .mask_errors = true,
    .generic_message = "An unexpected error occurred",
    .include_stack_traces = false,
    .include_error_codes = true,
};
```

### Tracing & APM

```zig
const config = api.TracingConfig{
    .enabled = true,
    .include_resolver_timings = true,
    .include_parsing = true,
    .include_validation = true,
    .apm_provider = .opentelemetry,
};
```

### Federation Support

```zig
const config = api.FederationConfig{
    .enabled = true,
    .version = .v2,
    .service_name = "users-service",
    .service_url = "http://localhost:4001/graphql",
};
```

## Subscriptions

### Configuration

```zig
const config = api.SubscriptionConfig{
    .protocol = .graphql_ws,
    .keep_alive = true,
    .keep_alive_interval_ms = 30000,
    .connection_timeout_ms = 30000,
    .max_retry_attempts = 5,
    .lazy = true,
};
```

## GraphQL Middleware

### Basic Middleware

```zig
const mw = api.graphqlMiddleware(.{
    .enable_complexity_analysis = true,
    .max_complexity = 1000,
    .enable_depth_limiting = true,
    .max_depth = 15,
    .enable_introspection = true,
    .paths = &.{"/graphql"},
});

try app.use(mw.handle);
```

### GraphQL CORS

```zig
const cors_mw = api.graphqlCors(.{
    .allowed_origins = &.{"https://example.com"},
    .allow_credentials = true,
});

try app.use(cors_mw.handle);
```

### GraphQL Rate Limiting

```zig
const rate_mw = api.graphqlRateLimit(.{
    .query_limit = 100,
    .mutation_limit = 50,
    .subscription_limit = 10,
    .window_seconds = 60,
});

try app.use(rate_mw.handle);
```

### GraphQL Tracing Middleware

```zig
const trace_mw = api.graphqlTracing(.{
    .enabled = true,
    .include_resolver_timings = true,
    .sample_rate = 1.0,
});

try app.use(trace_mw.handle);
```

## Full Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Production GraphQL API",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Create schema
    var schema = api.GraphQLSchema.init(allocator);
    defer schema.deinit();

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "users", .type_name = "User", .is_list = true },
            .{ .name = "user", .type_name = "User", .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            }},
        },
    });

    try schema.addObjectType(.{
        .name = "User",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "email", .type_name = "Email" },
        },
    });

    // Enable GraphQL with production config
    try app.enableGraphQL(&schema, .{
        .schema = &schema,
        .path = "/graphql",
        .playground_path = "/graphql/playground",
        .graphiql_path = "/graphql/graphiql",
        .apollo_sandbox_path = "/graphql/sandbox",
        .voyager_path = "/graphql/voyager",
        .enable_introspection = true,
        .enable_tracing = true,
        .mask_errors = true,
        .max_depth = 15,
        .max_complexity = 1000,
        .enable_caching = true,
        .cache_ttl_ms = 60000,
        .ui_config = .{
            .theme = .dark,
            .title = "My GraphQL API",
            .show_docs = true,
            .code_completion = true,
        },
    });

    // Add GraphQL middleware
    const gql_mw = api.graphqlMiddleware(.{
        .enable_complexity_analysis = true,
        .enable_depth_limiting = true,
    });
    try app.use(gql_mw.handle);

    try app.run(.{ .port = 8000 });
}
```

## See Also

- [GraphQL UI Guide](/guide/graphql-ui)
- [WebSocket Module](/api/websocket)
- [Middleware Module](/api/middleware)
