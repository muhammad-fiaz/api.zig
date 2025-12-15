# GraphQL Schema Definition

This guide covers advanced schema definition patterns in api.zig GraphQL.

## Overview

GraphQL schemas define the shape of your API. api.zig provides a type-safe schema builder with full support for the GraphQL specification.

## Type System

### Object Types

Object types are the most common type in GraphQL schemas:

```zig
try schema.addObjectType(.{
    .name = "User",
    .description = "A user in the system",
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "name", .type_name = "String", .is_non_null = true },
        .{ .name = "email", .type_name = "Email" },
        .{ .name = "role", .type_name = "UserRole", .is_non_null = true },
        .{ .name = "posts", .type_name = "Post", .is_list = true },
        .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
    },
});
```

### Input Types

Input types are used for mutation arguments:

```zig
try schema.addInputType("CreateUserInput", &.{
    .{ .name = "name", .type_name = "String", .is_non_null = true },
    .{ .name = "email", .type_name = "Email", .is_non_null = true },
    .{ .name = "role", .type_name = "UserRole", .default_value = "USER" },
}, "Input for creating a user");
```

### Enum Types

Enums define a fixed set of values:

```zig
try schema.addEnumType("UserRole", &.{
    .{ .name = "ADMIN", .description = "Full access" },
    .{ .name = "MODERATOR", .description = "Content moderation" },
    .{ .name = "USER", .description = "Standard user" },
    .{ .name = "GUEST", .description = "Read-only", .is_deprecated = true, .deprecation_reason = "Use USER instead" },
}, "User permission levels");
```

### Interface Types

Interfaces define common fields:

```zig
try schema.addInterfaceType("Node", &.{
    .{ .name = "id", .type_name = "ID", .is_non_null = true },
}, "Relay Node interface for pagination");

// Implement interface
try schema.addObjectType(.{
    .name = "User",
    .implements = &.{"Node"},
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "name", .type_name = "String", .is_non_null = true },
    },
});
```

### Union Types

Unions combine multiple types:

```zig
try schema.addUnionType("SearchResult", &.{
    "User", "Post", "Comment", "Tag",
}, "Search can return different types");
```

## Scalar Types

api.zig includes 30+ built-in scalar types:

### Standard Scalars

| Scalar | Zig Type | Description |
|--------|----------|-------------|
| `ID` | `[]const u8` | Unique identifier |
| `String` | `[]const u8` | UTF-8 string |
| `Int` | `i32` | 32-bit integer |
| `Float` | `f64` | 64-bit float |
| `Boolean` | `bool` | true/false |

### Date/Time Scalars

| Scalar | Format | Example |
|--------|--------|---------|
| `DateTime` | ISO 8601 | `2024-01-15T10:30:00Z` |
| `Date` | ISO 8601 | `2024-01-15` |
| `Time` | ISO 8601 | `10:30:00` |
| `Timestamp` | Unix | `1705312200` |
| `Duration` | ISO 8601 | `PT1H30M` |

### Validation Scalars

| Scalar | Validates |
|--------|-----------|
| `Email` | RFC 5322 email |
| `URL` | RFC 3986 URI |
| `UUID` | UUID v4 |
| `IPv4` | IPv4 address |
| `IPv6` | IPv6 address |
| `Phone` | E.164 phone |
| `PostalCode` | Postal code |

### Numeric Scalars

| Scalar | Range |
|--------|-------|
| `BigInt` | Arbitrary precision |
| `Decimal` | Arbitrary precision |
| `PositiveInt` | > 0 |
| `NonNegativeInt` | >= 0 |
| `NegativeInt` | < 0 |
| `PositiveFloat` | > 0.0 |

### Other Scalars

| Scalar | Description |
|--------|-------------|
| `JSON` | Arbitrary JSON |
| `Upload` | File upload |
| `Bytes` | Base64 binary |
| `Currency` | ISO 4217 |
| `Void` | No return |

## Root Types

### Query Type

```zig
try schema.setQueryType(.{
    .name = "Query",
    .fields = &.{
        .{ .name = "users", .type_name = "User", .is_list = true, .is_non_null = true },
        .{ .name = "user", .type_name = "User", .args = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
        }},
    },
});
```

### Mutation Type

```zig
try schema.setMutationType(.{
    .name = "Mutation",
    .fields = &.{
        .{ .name = "createUser", .type_name = "User", .args = &.{
            .{ .name = "input", .type_name = "CreateUserInput", .is_non_null = true },
        }},
    },
});
```

### Subscription Type

```zig
try schema.setSubscriptionType(.{
    .name = "Subscription",
    .fields = &.{
        .{ .name = "userCreated", .type_name = "User", .is_non_null = true },
    },
});
```

## Field Modifiers

### Non-Null Fields

```zig
.{ .name = "id", .type_name = "ID", .is_non_null = true }
// GraphQL: id: ID!
```

### List Fields

```zig
.{ .name = "posts", .type_name = "Post", .is_list = true }
// GraphQL: posts: [Post]
```

### Non-Null List with Non-Null Items

```zig
.{ .name = "tags", .type_name = "String", .is_list = true, .is_non_null = true, .list_item_non_null = true }
// GraphQL: tags: [String!]!
```

## Arguments

### Required Arguments

```zig
.args = &.{
    .{ .name = "id", .type_name = "ID", .is_non_null = true },
}
```

### Optional Arguments with Defaults

```zig
.args = &.{
    .{ .name = "limit", .type_name = "Int", .default_value = "10" },
    .{ .name = "offset", .type_name = "Int", .default_value = "0" },
}
```

## Deprecation

```zig
.{
    .name = "oldField",
    .type_name = "String",
    .is_deprecated = true,
    .deprecation_reason = "Use newField instead",
}
```

## SDL Export

Export schema as SDL:

```zig
const sdl = try schema.toSDL(allocator);
defer allocator.free(sdl);
std.debug.print("{s}\n", .{sdl});
```

Output:

```graphql
type Query {
  users: [User]!
  user(id: ID!): User
}

type User {
  id: ID!
  name: String!
  email: Email
  role: UserRole!
}

enum UserRole {
  ADMIN
  USER
  GUEST
}
```

## See Also

- [GraphQL Guide](/guide/graphql)
- [GraphQL Resolvers](/guide/graphql-resolvers)
- [GraphQL API](/api/graphql)
