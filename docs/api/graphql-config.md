# GraphQL Configuration API

Complete configuration reference for GraphQL in api.zig.

## GraphQLConfig

Main configuration for enabling GraphQL.

```zig
pub const GraphQLConfig = struct {
    /// GraphQL schema (required)
    schema: *Schema,
    
    /// GraphQL endpoint path
    path: []const u8 = "/graphql",
    
    /// GraphiQL UI path (null to disable)
    graphiql_path: ?[]const u8 = "/graphql/graphiql",
    
    /// Playground path (null to disable)
    playground_path: ?[]const u8 = "/graphql/playground",
    
    /// Apollo Sandbox path (null to disable)
    apollo_sandbox_path: ?[]const u8 = null,
    
    /// Altair path (null to disable)
    altair_path: ?[]const u8 = null,
    
    /// Voyager path (null to disable)
    voyager_path: ?[]const u8 = null,
    
    /// Enable playground/UI
    enable_playground: bool = true,
    
    /// Enable schema introspection
    enable_introspection: bool = true,
    
    /// Maximum query depth
    max_depth: u32 = 15,
    
    /// Maximum query complexity
    max_complexity: u32 = 1000,
    
    /// Enable query batching
    enable_batching: bool = false,
    
    /// Maximum batch size
    max_batch_size: u32 = 10,
    
    /// Enable Apollo tracing
    enable_tracing: bool = false,
    
    /// Enable persisted queries
    enable_persisted_queries: bool = false,
    
    /// Only allow persisted queries
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
    
    /// Subscription configuration
    subscription_config: SubscriptionConfig = .{},
    
    /// UI configuration
    ui_config: GraphQLUIConfig = .{},
    
    /// Complexity configuration
    complexity_config: ComplexityConfig = .{},
    
    /// Depth configuration
    depth_config: DepthConfig = .{},
    
    /// Response cache configuration
    cache_config: ResponseCacheConfig = .{},
    
    /// Persisted queries configuration
    persisted_queries_config: PersistedQueriesConfig = .{},
    
    /// Federation configuration
    federation_config: FederationConfig = .{},
    
    /// Tracing configuration
    tracing_config: TracingConfig = .{},
    
    /// Error configuration
    error_config: ErrorConfig = .{},
};
```

## SubscriptionConfig

```zig
pub const SubscriptionConfig = struct {
    /// WebSocket protocol
    protocol: SubscriptionProtocol = .graphql_ws,
    
    /// Enable keep-alive pings
    keep_alive: bool = true,
    
    /// Keep-alive interval (ms)
    keep_alive_interval_ms: u32 = 30000,
    
    /// Connection timeout (ms)
    connection_timeout_ms: u32 = 30000,
    
    /// Max retry attempts
    max_retry_attempts: u32 = 5,
    
    /// Retry delay (ms)
    retry_delay_ms: u32 = 1000,
    
    /// Lazy connection
    lazy: bool = true,
    
    /// Max subscriptions per connection
    max_subscriptions: u32 = 100,
    
    /// ACK timeout (ms)
    ack_timeout_ms: u32 = 10000,
};

pub const SubscriptionProtocol = enum {
    graphql_ws,
    subscriptions_transport_ws,
    sse,
};
```

## ComplexityConfig

```zig
pub const ComplexityConfig = struct {
    /// Enable complexity analysis
    enabled: bool = false,
    
    /// Maximum allowed complexity
    max_complexity: u32 = 1000,
    
    /// Default field complexity
    default_field_complexity: u32 = 1,
    
    /// List multiplier
    list_multiplier: u32 = 10,
    
    /// Ignore introspection queries
    ignore_introspection: bool = true,
};
```

## DepthConfig

```zig
pub const DepthConfig = struct {
    /// Enable depth limiting
    enabled: bool = false,
    
    /// Maximum query depth
    max_depth: u32 = 15,
    
    /// Ignore introspection queries
    ignore_introspection: bool = true,
    
    /// Custom depth limits per operation
    operation_limits: []const OperationLimit = &.{},
};

pub const OperationLimit = struct {
    operation_name: []const u8,
    max_depth: u32,
};
```

## ResponseCacheConfig

```zig
pub const ResponseCacheConfig = struct {
    /// Enable response caching
    enabled: bool = false,
    
    /// Maximum cache entries
    max_size: u32 = 1000,
    
    /// Default TTL (ms)
    default_ttl_ms: u64 = 60000,
    
    /// Skip caching mutations
    skip_mutations: bool = true,
    
    /// Skip caching subscriptions
    skip_subscriptions: bool = true,
    
    /// Cache key prefix
    key_prefix: []const u8 = "gql:",
};
```

## PersistedQueriesConfig

```zig
pub const PersistedQueriesConfig = struct {
    /// Enable persisted queries
    enabled: bool = false,
    
    /// Only allow persisted queries
    only_persisted: bool = false,
    
    /// Use SHA256 for query hashing
    use_sha256: bool = true,
    
    /// Cache TTL for APQ (ms)
    cache_ttl_ms: u64 = 86400000,
};
```

## FederationConfig

```zig
pub const FederationConfig = struct {
    /// Enable Apollo Federation
    enabled: bool = false,
    
    /// Federation version
    version: FederationVersion = .v2,
    
    /// Service name
    service_name: []const u8 = "",
    
    /// Service URL
    service_url: []const u8 = "",
    
    /// Service list (for gateway)
    service_list: []const ServiceDefinition = &.{},
    
    /// Schema polling interval (ms)
    poll_interval_ms: u32 = 10000,
    
    /// Enable health checks
    health_check: bool = true,
};

pub const FederationVersion = enum {
    v1,
    v2,
};

pub const ServiceDefinition = struct {
    name: []const u8,
    url: []const u8,
};
```

## TracingConfig

```zig
pub const TracingConfig = struct {
    /// Enable tracing
    enabled: bool = false,
    
    /// Include resolver timings
    include_resolver_timings: bool = true,
    
    /// Include parsing time
    include_parsing: bool = true,
    
    /// Include validation time
    include_validation: bool = true,
    
    /// APM provider
    apm_provider: APMProvider = .none,
    
    /// Sample rate (0.0 - 1.0)
    sample_rate: f32 = 1.0,
};

pub const APMProvider = enum {
    none,
    opentelemetry,
    datadog,
    newrelic,
    jaeger,
};
```

## ErrorConfig

```zig
pub const ErrorConfig = struct {
    /// Mask errors in responses
    mask_errors: bool = true,
    
    /// Generic error message
    generic_message: []const u8 = "An unexpected error occurred",
    
    /// Include stack traces
    include_stack_traces: bool = false,
    
    /// Include error codes
    include_error_codes: bool = true,
    
    /// Log errors
    log_errors: bool = true,
};
```

## DataLoaderConfig

```zig
pub const DataLoaderConfig = struct {
    /// Enable DataLoader
    enabled: bool = false,
    
    /// Batch scheduling delay (ms)
    batch_delay_ms: u32 = 0,
    
    /// Maximum batch size
    max_batch_size: u32 = 100,
    
    /// Enable caching
    cache: bool = true,
};
```

## Usage Example

```zig
try app.enableGraphQL(&schema, .{
    .path = "/graphql",
    .graphiql_path = "/graphql/graphiql",
    .playground_path = "/graphql/playground",
    
    // Security
    .enable_introspection = true,
    .max_depth = 15,
    .max_complexity = 1000,
    .mask_errors = true,
    
    // Performance
    .enable_caching = true,
    .cache_ttl_ms = 60000,
    .enable_batching = true,
    
    // Subscriptions
    .enable_subscriptions = true,
    .subscription_config = .{
        .protocol = .graphql_ws,
        .keep_alive = true,
    },
    
    // UI
    .ui_config = .{
        .theme = .dark,
        .title = "API Explorer",
        .show_docs = true,
    },
    
    // Tracing
    .enable_tracing = true,
    .tracing_config = .{
        .apm_provider = .opentelemetry,
        .sample_rate = 0.1,
    },
});
```

## See Also

- [GraphQL Guide](/guide/graphql)
- [GraphQL API](/api/graphql)
