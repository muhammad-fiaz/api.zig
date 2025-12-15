# Basic GraphQL Example

This example demonstrates how to set up a complete GraphQL API with api.zig, including schema definition, multiple UI providers, queries, mutations, and subscriptions.

## Full Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "GraphQL API",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Create schema
    var schema = api.graphql.Schema.init(allocator);
    defer schema.deinit();

    // Define types
    try schema.addEnumType("UserRole", &.{
        .{ .name = "ADMIN" },
        .{ .name = "USER" },
        .{ .name = "GUEST" },
    }, null);

    try schema.addObjectType(.{
        .name = "User",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "email", .type_name = "Email" },
            .{ .name = "role", .type_name = "UserRole", .is_non_null = true },
        },
    });

    // Query type
    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "users", .type_name = "User", .is_list = true },
            .{ .name = "user", .type_name = "User", .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            }},
        },
    });

    // Mutation type
    try schema.setMutationType(.{
        .name = "Mutation",
        .fields = &.{
            .{ .name = "createUser", .type_name = "User", .args = &.{
                .{ .name = "name", .type_name = "String", .is_non_null = true },
                .{ .name = "email", .type_name = "Email", .is_non_null = true },
            }},
        },
    });

    // Enable GraphQL with all UIs
    try app.enableGraphQL(&schema, .{
        .path = "/graphql",
        .graphiql_path = "/graphql/graphiql",
        .playground_path = "/graphql/playground",
        .apollo_sandbox_path = "/graphql/sandbox",
        .voyager_path = "/graphql/voyager",
        .ui_config = .{
            .theme = .dark,
            .title = "My API Explorer",
        },
    });

    try app.run(.{ .port = 8080 });
}
```

## Schema Definition

### Object Types

```zig
try schema.addObjectType(.{
    .name = "User",
    .description = "A user in the system",
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "name", .type_name = "String", .is_non_null = true },
        .{ .name = "email", .type_name = "Email" },
        .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
        .{ .name = "posts", .type_name = "Post", .is_list = true },
    },
});
```

### Input Types

```zig
try schema.addInputType("CreateUserInput", &.{
    .{ .name = "name", .type_name = "String", .is_non_null = true },
    .{ .name = "email", .type_name = "Email", .is_non_null = true },
    .{ .name = "role", .type_name = "UserRole", .default_value = "USER" },
}, "Input for creating a new user");
```

### Enum Types

```zig
try schema.addEnumType("UserRole", &.{
    .{ .name = "ADMIN", .description = "Full access" },
    .{ .name = "USER", .description = "Standard access" },
    .{ .name = "GUEST", .description = "Read-only" },
}, "User permission roles");
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
}, "Search result types");
```

## Queries

Define read operations in the Query type:

```zig
try schema.setQueryType(.{
    .name = "Query",
    .fields = &.{
        // Get all items
        .{
            .name = "users",
            .type_name = "User",
            .is_list = true,
            .is_non_null = true,
        },
        // Get by ID
        .{
            .name = "user",
            .type_name = "User",
            .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            },
        },
        // Search with filters
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

### Example Query

```graphql
query GetUsers {
  users {
    id
    name
    email
    role
  }
}

query GetUser($id: ID!) {
  user(id: $id) {
    name
    email
    posts {
      title
    }
  }
}
```

## Mutations

Define write operations in the Mutation type:

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

### Example Mutation

```graphql
mutation CreateUser($input: CreateUserInput!) {
  createUser(input: $input) {
    id
    name
    email
  }
}
```

## UI Providers

api.zig includes 5 GraphQL UI providers:

| UI | Path | Best For |
|----|------|----------|
| GraphiQL | `/graphql/graphiql` | Modern development |
| Playground | `/graphql/playground` | Feature-rich editing |
| Apollo Sandbox | `/graphql/sandbox` | Apollo ecosystem |
| Altair | `/graphql/altair` | Advanced features |
| Voyager | `/graphql/voyager` | Schema visualization |

### Enable All UIs

```zig
try app.enableAllGraphQLUIs(&schema, .{
    .base_path = "/graphql",
    .theme = .dark,
});
```

## Configuration Options

```zig
try app.enableGraphQL(&schema, .{
    .path = "/graphql",
    
    // UI paths (null to disable)
    .graphiql_path = "/graphql/graphiql",
    .playground_path = "/graphql/playground",
    .apollo_sandbox_path = null,  // disabled
    
    // Security
    .enable_introspection = true,
    .max_depth = 15,
    .max_complexity = 1000,
    
    // Performance
    .enable_caching = true,
    .cache_ttl_ms = 60000,
    .enable_batching = true,
    
    // UI customization
    .ui_config = .{
        .theme = .dark,
        .title = "API Explorer",
        .show_docs = true,
        .code_completion = true,
    },
});
```

## Running the Example

```bash
# Build and run
zig build run-example

# Or run directly
zig run examples/graphql.zig
```

Then visit:
- http://localhost:8080/graphql/graphiql - GraphiQL IDE
- http://localhost:8080/graphql/playground - Playground
- http://localhost:8080/graphql/voyager - Schema visualization

## Sample Queries

### Get All Users

```graphql
query {
  users {
    id
    name
    email
    role
  }
}
```

### Get User with Posts

```graphql
query GetUserWithPosts($id: ID!) {
  user(id: $id) {
    name
    email
    posts {
      id
      title
      status
    }
  }
}
```

### Create User

```graphql
mutation CreateUser {
  createUser(input: {
    name: "Alice"
    email: "alice@example.com"
    role: USER
  }) {
    id
    name
  }
}
```

## See Also

- [GraphQL Subscriptions](/examples/graphql-subscriptions) - Real-time updates
- [GraphQL Guide](/guide/graphql) - Complete guide
- [GraphQL API Reference](/api/graphql) - Full API documentation
