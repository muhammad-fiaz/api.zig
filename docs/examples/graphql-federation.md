# GraphQL Federation Example

This example demonstrates Apollo Federation with api.zig for building a distributed GraphQL architecture across multiple services.

## Overview

Apollo Federation allows you to compose multiple GraphQL services into a single unified API. Each service owns a portion of the schema and can be developed independently.

## Gateway Service

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Federation Gateway",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Configure federation gateway
    try app.enableGraphQL(null, .{
        .path = "/graphql",
        .graphiql_path = "/graphql/graphiql",
        .federation_config = .{
            .enabled = true,
            .version = .v2,
            .service_list = &.{
                .{ .name = "users", .url = "http://localhost:4001/graphql" },
                .{ .name = "products", .url = "http://localhost:4002/graphql" },
                .{ .name = "reviews", .url = "http://localhost:4003/graphql" },
            },
            .poll_interval_ms = 10000,
        },
    });

    std.debug.print("Federation Gateway running at http://localhost:4000/graphql\n", .{});
    try app.run(.{ .port = 4000 });
}
```

## Users Service

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    var schema = api.graphql.Schema.init(allocator);
    defer schema.deinit();

    // User type with @key directive for federation
    try schema.addObjectType(.{
        .name = "User",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "email", .type_name = "Email", .is_non_null = true },
        },
        .directives = &.{
            .{ .name = "key", .args = "fields: \"id\"" },
        },
    });

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "users", .type_name = "User", .is_list = true },
            .{ .name = "user", .type_name = "User", .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            }},
        },
    });

    try app.enableGraphQL(&schema, .{
        .path = "/graphql",
        .federation_config = .{
            .enabled = true,
            .version = .v2,
            .service_name = "users",
            .service_url = "http://localhost:4001/graphql",
        },
    });

    std.debug.print("Users service running at http://localhost:4001/graphql\n", .{});
    try app.run(.{ .port = 4001 });
}
```

## Products Service

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    var schema = api.graphql.Schema.init(allocator);
    defer schema.deinit();

    try schema.addObjectType(.{
        .name = "Product",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "price", .type_name = "Float", .is_non_null = true },
            .{ .name = "inStock", .type_name = "Boolean", .is_non_null = true },
        },
        .directives = &.{
            .{ .name = "key", .args = "fields: \"id\"" },
        },
    });

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "products", .type_name = "Product", .is_list = true },
            .{ .name = "product", .type_name = "Product", .args = &.{
                .{ .name = "id", .type_name = "ID", .is_non_null = true },
            }},
        },
    });

    try app.enableGraphQL(&schema, .{
        .path = "/graphql",
        .federation_config = .{
            .enabled = true,
            .version = .v2,
            .service_name = "products",
            .service_url = "http://localhost:4002/graphql",
        },
    });

    std.debug.print("Products service running at http://localhost:4002/graphql\n", .{});
    try app.run(.{ .port = 4002 });
}
```

## Reviews Service

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    var schema = api.graphql.Schema.init(allocator);
    defer schema.deinit();

    // Review type
    try schema.addObjectType(.{
        .name = "Review",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "body", .type_name = "String", .is_non_null = true },
            .{ .name = "rating", .type_name = "Int", .is_non_null = true },
            .{ .name = "author", .type_name = "User", .is_non_null = true },
            .{ .name = "product", .type_name = "Product", .is_non_null = true },
        },
        .directives = &.{
            .{ .name = "key", .args = "fields: \"id\"" },
        },
    });

    // Extend User from users service
    try schema.extendType(.{
        .name = "User",
        .fields = &.{
            .{ .name = "reviews", .type_name = "Review", .is_list = true },
        },
        .directives = &.{
            .{ .name = "key", .args = "fields: \"id\"" },
            .{ .name = "external" },
        },
    });

    // Extend Product from products service
    try schema.extendType(.{
        .name = "Product",
        .fields = &.{
            .{ .name = "reviews", .type_name = "Review", .is_list = true },
        },
        .directives = &.{
            .{ .name = "key", .args = "fields: \"id\"" },
            .{ .name = "external" },
        },
    });

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "reviews", .type_name = "Review", .is_list = true },
        },
    });

    try app.enableGraphQL(&schema, .{
        .path = "/graphql",
        .federation_config = .{
            .enabled = true,
            .version = .v2,
            .service_name = "reviews",
            .service_url = "http://localhost:4003/graphql",
        },
    });

    std.debug.print("Reviews service running at http://localhost:4003/graphql\n", .{});
    try app.run(.{ .port = 4003 });
}
```

## Running Federation

Start all services:

```bash
# Terminal 1 - Users service
zig run examples/federation/users.zig

# Terminal 2 - Products service  
zig run examples/federation/products.zig

# Terminal 3 - Reviews service
zig run examples/federation/reviews.zig

# Terminal 4 - Gateway
zig run examples/federation/gateway.zig
```

## Querying the Gateway

Access the unified API at http://localhost:4000/graphql:

```graphql
query {
  users {
    id
    name
    email
    reviews {
      rating
      body
      product {
        name
        price
      }
    }
  }
}
```

## Federation Configuration

```zig
.federation_config = .{
    // Enable federation
    .enabled = true,
    
    // Federation version
    .version = .v2,  // or .v1
    
    // Service identification
    .service_name = "users",
    .service_url = "http://localhost:4001/graphql",
    
    // Gateway-only settings
    .service_list = &.{...},
    .poll_interval_ms = 10000,
    
    // Health checking
    .health_check = true,
    .health_check_interval_ms = 30000,
},
```

## See Also

- [Basic GraphQL](/examples/graphql-basic) - Simple GraphQL setup
- [GraphQL Guide](/guide/graphql) - Complete documentation
- [Apollo Federation Docs](https://www.apollographql.com/docs/federation/)
