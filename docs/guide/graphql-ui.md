# GraphQL UI Customization

api.zig provides 5 GraphQL UI providers, each with extensive customization options for theming, branding, and functionality.

## Available UI Providers

### 1. GraphiQL

The official GraphQL IDE with the Explorer plugin.

```zig
const html = api.graphiql("/graphql");

// Or with full configuration
const html = api.graphiqlWithConfig(.{
    .theme = .dark,
    .title = "API Explorer",
    .endpoint = "/graphql",
    .show_docs = true,
    .show_history = true,
    .enable_persistence = true,
    .code_completion = true,
    .default_query =
        \\query {
        \\  users {
        \\    id
        \\    name
        \\  }
        \\}
    ,
});
```

**Features:**
- Documentation explorer
- Query history
- Syntax highlighting
- Auto-completion
- Variable editor
- Response formatting

### 2. GraphQL Playground

Feature-rich GraphQL IDE with tabs and settings.

```zig
const html = api.graphqlPlayground("/graphql");

// With configuration
const html = api.graphqlPlaygroundWithConfig(.{
    .theme = .dark,
    .schema_polling = true,
    .schema_polling_interval_ms = 2000,
    .title = "Playground",
});
```

**Features:**
- Multiple tabs
- Schema polling
- Request tracing
- Settings panel
- Syntax highlighting

### 3. Apollo Sandbox

Apollo's embeddable GraphQL IDE.

```zig
const html = api.apolloSandbox("/graphql");

// With configuration
const html = api.apolloSandboxWithConfig(.{
    .title = "Apollo Sandbox",
    .credentials = .include,
    .endpoint = "/graphql",
});
```

**Features:**
- Modern interface
- Operation collections
- Response visualization
- Apollo ecosystem integration

### 4. Altair GraphQL Client

Full-featured GraphQL client with advanced capabilities.

```zig
const html = api.altairGraphQL("/graphql");

// With configuration
const html = api.altairGraphQLWithConfig(.{
    .theme = .dark,
    .title = "Altair Client",
    .endpoint = "/graphql",
});
```

**Features:**
- File uploads
- Binary responses
- Request scripting
- Environment variables
- Plugin support

### 5. GraphQL Voyager

Interactive schema visualization tool.

```zig
const html = api.graphqlVoyager("/graphql");

// With configuration
const html = api.graphqlVoyagerWithConfig(.{
    .title = "Schema Visualization",
    .endpoint = "/graphql",
});
```

**Features:**
- Interactive graph
- Type exploration
- Relationship visualization
- Schema documentation

## Enabling All UIs

```zig
try app.enableAllGraphQLUIs(&schema, .{
    .base_path = "/graphql",
    .theme = .dark,
    .title = "My API",
});

// Results in:
// GET /graphql/graphiql  - GraphiQL
// GET /graphql/playground - GraphQL Playground
// GET /graphql/sandbox   - Apollo Sandbox
// GET /graphql/altair    - Altair
// GET /graphql/voyager   - Voyager
```

## UI Configuration Options

### GraphQLUIConfig

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
    
    /// Default headers for requests
    default_headers: []const HeaderPair = &.{},
    
    /// Initial query to display
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
    
    /// Custom CSS styles
    custom_css: ?[]const u8 = null,
    
    /// Custom JavaScript
    custom_js: ?[]const u8 = null,
    
    /// Logo URL for branding
    logo_url: ?[]const u8 = null,
    
    /// Credentials policy
    credentials: CredentialsPolicy = .same_origin,
};
```

### Themes

```zig
pub const GraphQLUITheme = enum {
    light,
    dark,
    system,  // Follow OS preference
};
```

### Credentials Policy

```zig
pub const CredentialsPolicy = enum {
    omit,        // Never send credentials
    same_origin, // Send for same-origin requests only
    include,     // Always send credentials
};
```

## Theming Examples

### Dark Theme with Custom Branding

```zig
try app.enableGraphQL(&schema, .{
    .ui_config = .{
        .theme = .dark,
        .title = "ACME API Explorer",
        .logo_url = "https://example.com/logo.svg",
        .custom_css =
            \\.graphiql-container {
            \\  --color-primary: #6366f1;
            \\  --font-family-mono: 'JetBrains Mono', monospace;
            \\}
            \\.graphiql-logo {
            \\  max-height: 32px;
            \\}
        ,
    },
});
```

### Light Theme for Documentation

```zig
try app.enableGraphQL(&schema, .{
    .ui_config = .{
        .theme = .light,
        .title = "API Documentation",
        .show_docs = true,
        .enable_persistence = false,
        .default_query =
            \\# Welcome! Try this query:
            \\query {
            \\  __schema {
            \\    types {
            \\      name
            \\    }
            \\  }
            \\}
        ,
    },
});
```

### System Theme Following OS

```zig
try app.enableGraphQL(&schema, .{
    .ui_config = .{
        .theme = .system,
        .custom_css =
            \\@media (prefers-color-scheme: dark) {
            \\  .graphiql-container { background: #1a1a2e; }
            \\}
            \\@media (prefers-color-scheme: light) {
            \\  .graphiql-container { background: #ffffff; }
            \\}
        ,
    },
});
```

## Authentication Integration

### Default Authorization Header

```zig
try app.enableGraphQL(&schema, .{
    .ui_config = .{
        .default_headers = &.{
            .{ .key = "Authorization", .value = "Bearer <your-token>" },
            .{ .key = "X-API-Key", .value = "<your-api-key>" },
        },
        .credentials = .include,
    },
});
```

### Custom Auth Script

```zig
try app.enableGraphQL(&schema, .{
    .ui_config = .{
        .custom_js =
            \\// Add auth token before each request
            \\window.graphqlFetch = (url, options) => {
            \\  const token = localStorage.getItem('auth_token');
            \\  if (token) {
            \\    options.headers = {
            \\      ...options.headers,
            \\      'Authorization': `Bearer ${token}`
            \\    };
            \\  }
            \\  return fetch(url, options);
            \\};
        ,
    },
});
```

## Subscription Configuration

### WebSocket Endpoint

```zig
try app.enableGraphQL(&schema, .{
    .path = "/graphql",
    .enable_subscriptions = true,
    .ui_config = .{
        .endpoint = "/graphql",
        .subscription_endpoint = "ws://localhost:8000/graphql/ws",
    },
});
```

## Custom Handler Routes

### Manual UI Registration

```zig
// Register GraphiQL manually
app.router.get("/explorer", struct {
    fn handle(ctx: *api.Context) !void {
        const html = api.graphiqlWithConfig(.{
            .theme = .dark,
            .endpoint = "/api/graphql",
            .title = "Custom Explorer",
        });
        ctx.response.setHeader("Content-Type", "text/html; charset=utf-8");
        try ctx.response.send(html);
    }
}.handle);

// Register Voyager for schema visualization
app.router.get("/schema-viz", struct {
    fn handle(ctx: *api.Context) !void {
        const html = api.graphqlVoyager("/api/graphql");
        ctx.response.setHeader("Content-Type", "text/html; charset=utf-8");
        try ctx.response.send(html);
    }
}.handle);
```

## Best Practices

### Development Environment

```zig
const is_dev = std.mem.eql(u8, std.process.getEnv("ENV") orelse "dev", "dev");

try app.enableGraphQL(&schema, .{
    .enable_introspection = is_dev,
    .playground_path = if (is_dev) "/graphql/playground" else null,
    .graphiql_path = if (is_dev) "/graphql/graphiql" else null,
    .ui_config = .{
        .theme = .dark,
        .show_docs = is_dev,
    },
});
```

### Public API Documentation

```zig
try app.enableGraphQL(&schema, .{
    // Only enable Voyager for schema exploration
    .voyager_path = "/graphql/docs",
    .graphiql_path = null,
    .playground_path = null,
    .enable_introspection = true,  // Needed for Voyager
    .ui_config = .{
        .theme = .light,
        .title = "API Schema Documentation",
    },
});
```

## See Also

- [GraphQL Guide](/guide/graphql) - Getting started with GraphQL
- [GraphQL API Reference](/api/graphql) - Complete API documentation
- [Middleware](/guide/middleware) - Authentication middleware
