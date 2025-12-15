# GraphQL UI Providers API

api.zig includes 5 GraphQL UI providers for interactive schema exploration and query execution.

## UI Providers

### GraphQLUIProvider Enum

```zig
pub const GraphQLUIProvider = enum {
    graphiql,
    playground,
    apollo_sandbox,
    altair,
    voyager,
};
```

## GraphiQL

The official GraphQL IDE with Explorer plugin.

### graphiql

```zig
pub fn graphiql(endpoint: []const u8) []const u8
```

Returns HTML for GraphiQL UI.

**Parameters:**
- `endpoint` - GraphQL endpoint URL

**Example:**

```zig
const html = api.graphiql("/graphql");
```

### graphiqlWithConfig

```zig
pub fn graphiqlWithConfig(config: GraphQLUIConfig) []const u8
```

Returns HTML for GraphiQL with custom configuration.

**Example:**

```zig
const html = api.graphiqlWithConfig(.{
    .theme = .dark,
    .title = "API Explorer",
    .endpoint = "/graphql",
    .show_docs = true,
    .code_completion = true,
});
```

## GraphQL Playground

Feature-rich GraphQL IDE with tabs and settings.

### graphqlPlayground

```zig
pub fn graphqlPlayground(endpoint: []const u8) []const u8
```

**Example:**

```zig
const html = api.graphqlPlayground("/graphql");
```

### graphqlPlaygroundWithConfig

```zig
pub fn graphqlPlaygroundWithConfig(config: GraphQLUIConfig) []const u8
```

## Apollo Sandbox

Apollo's embeddable GraphQL IDE.

### apolloSandbox

```zig
pub fn apolloSandbox(endpoint: []const u8) []const u8
```

### apolloSandboxWithConfig

```zig
pub fn apolloSandboxWithConfig(config: GraphQLUIConfig) []const u8
```

## Altair GraphQL Client

Full-featured GraphQL client with file upload support.

### altairGraphQL

```zig
pub fn altairGraphQL(endpoint: []const u8) []const u8
```

### altairGraphQLWithConfig

```zig
pub fn altairGraphQLWithConfig(config: GraphQLUIConfig) []const u8
```

## GraphQL Voyager

Interactive schema visualization.

### graphqlVoyager

```zig
pub fn graphqlVoyager(endpoint: []const u8) []const u8
```

### graphqlVoyagerWithConfig

```zig
pub fn graphqlVoyagerWithConfig(config: GraphQLUIConfig) []const u8
```

## Generic UI Generator

### generateGraphQLUI

```zig
pub fn generateGraphQLUI(config: GraphQLUIConfig) []const u8
```

Generate UI HTML for any provider.

**Example:**

```zig
const html = api.generateGraphQLUI(.{
    .provider = .playground,
    .theme = .dark,
    .title = "My API",
    .endpoint = "/graphql",
});
```

## GraphQLUIConfig

Complete configuration options for all UI providers.

```zig
pub const GraphQLUIConfig = struct {
    /// UI provider to use
    provider: GraphQLUIProvider = .graphiql,
    
    /// Theme preference
    theme: GraphQLUITheme = .dark,
    
    /// Page title
    title: []const u8 = "GraphQL Explorer",
    
    /// GraphQL endpoint URL
    endpoint: []const u8 = "/graphql",
    
    /// WebSocket endpoint for subscriptions
    subscription_endpoint: ?[]const u8 = null,
    
    /// Enable schema polling
    schema_polling: bool = false,
    
    /// Schema polling interval (ms)
    schema_polling_interval_ms: u32 = 2000,
    
    /// Show documentation explorer
    show_docs: bool = true,
    
    /// Show query history
    show_history: bool = true,
    
    /// Persist queries in localStorage
    enable_persistence: bool = true,
    
    /// Default headers
    default_headers: []const HeaderPair = &.{},
    
    /// Initial query
    default_query: ?[]const u8 = null,
    
    /// Initial variables
    default_variables: ?[]const u8 = null,
    
    /// Enable keyboard shortcuts
    enable_shortcuts: bool = true,
    
    /// Editor tab size
    editor_tab_size: u8 = 2,
    
    /// Editor font size (px)
    editor_font_size: u8 = 14,
    
    /// Enable syntax highlighting
    syntax_highlighting: bool = true,
    
    /// Enable code completion
    code_completion: bool = true,
    
    /// Custom CSS
    custom_css: ?[]const u8 = null,
    
    /// Custom JavaScript
    custom_js: ?[]const u8 = null,
    
    /// Logo URL
    logo_url: ?[]const u8 = null,
    
    /// Credentials policy
    credentials: CredentialsPolicy = .same_origin,
};
```

## GraphQLUITheme

```zig
pub const GraphQLUITheme = enum {
    light,
    dark,
    system,
};
```

## CredentialsPolicy

```zig
pub const CredentialsPolicy = enum {
    omit,
    same_origin,
    include,
};
```

## HeaderPair

```zig
pub const HeaderPair = struct {
    key: []const u8,
    value: []const u8,
};
```

## See Also

- [GraphQL Guide](/guide/graphql-ui)
- [GraphQL API](/api/graphql)
