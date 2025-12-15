# GraphQL Schema API

API reference for GraphQL schema definition in api.zig.

## Schema

### Schema.init

```zig
pub fn init(allocator: std.mem.Allocator) Schema
```

Create a new GraphQL schema.

**Example:**

```zig
var schema = api.graphql.Schema.init(allocator);
defer schema.deinit();
```

### Schema.deinit

```zig
pub fn deinit(self: *Schema) void
```

Free schema resources.

## Type Definitions

### setQueryType

```zig
pub fn setQueryType(self: *Schema, type_def: ObjectTypeDefinition) !void
```

Set the root Query type.

**Example:**

```zig
try schema.setQueryType(.{
    .name = "Query",
    .fields = &.{
        .{ .name = "users", .type_name = "User", .is_list = true },
    },
});
```

### setMutationType

```zig
pub fn setMutationType(self: *Schema, type_def: ObjectTypeDefinition) !void
```

Set the root Mutation type.

### setSubscriptionType

```zig
pub fn setSubscriptionType(self: *Schema, type_def: ObjectTypeDefinition) !void
```

Set the root Subscription type.

### addObjectType

```zig
pub fn addObjectType(self: *Schema, type_def: ObjectTypeDefinition) !void
```

Add a custom object type.

**Example:**

```zig
try schema.addObjectType(.{
    .name = "User",
    .description = "A user account",
    .fields = &.{
        .{ .name = "id", .type_name = "ID", .is_non_null = true },
        .{ .name = "name", .type_name = "String", .is_non_null = true },
    },
});
```

### addInputType

```zig
pub fn addInputType(
    self: *Schema,
    name: []const u8,
    fields: []const InputFieldDefinition,
    description: ?[]const u8,
) !void
```

Add an input type for mutations.

**Example:**

```zig
try schema.addInputType("CreateUserInput", &.{
    .{ .name = "name", .type_name = "String", .is_non_null = true },
    .{ .name = "email", .type_name = "Email", .is_non_null = true },
}, "Input for creating a user");
```

### addEnumType

```zig
pub fn addEnumType(
    self: *Schema,
    name: []const u8,
    values: []const EnumValueDefinition,
    description: ?[]const u8,
) !void
```

Add an enum type.

**Example:**

```zig
try schema.addEnumType("UserRole", &.{
    .{ .name = "ADMIN" },
    .{ .name = "USER" },
    .{ .name = "GUEST" },
}, "User roles");
```

### addInterfaceType

```zig
pub fn addInterfaceType(
    self: *Schema,
    name: []const u8,
    fields: []const FieldDefinition,
    description: ?[]const u8,
) !void
```

Add an interface type.

### addUnionType

```zig
pub fn addUnionType(
    self: *Schema,
    name: []const u8,
    types: []const []const u8,
    description: ?[]const u8,
) !void
```

Add a union type.

## Type Definition Structs

### ObjectTypeDefinition

```zig
pub const ObjectTypeDefinition = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    fields: []const FieldDefinition = &.{},
    implements: []const []const u8 = &.{},
    directives: []const DirectiveDefinition = &.{},
};
```

### FieldDefinition

```zig
pub const FieldDefinition = struct {
    name: []const u8,
    type_name: []const u8,
    description: ?[]const u8 = null,
    args: []const ArgumentDefinition = &.{},
    is_non_null: bool = false,
    is_list: bool = false,
    list_item_non_null: bool = false,
    is_deprecated: bool = false,
    deprecation_reason: ?[]const u8 = null,
};
```

### ArgumentDefinition

```zig
pub const ArgumentDefinition = struct {
    name: []const u8,
    type_name: []const u8,
    description: ?[]const u8 = null,
    is_non_null: bool = false,
    default_value: ?[]const u8 = null,
};
```

### InputFieldDefinition

```zig
pub const InputFieldDefinition = struct {
    name: []const u8,
    type_name: []const u8,
    description: ?[]const u8 = null,
    is_non_null: bool = false,
    default_value: ?[]const u8 = null,
};
```

### EnumValueDefinition

```zig
pub const EnumValueDefinition = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    is_deprecated: bool = false,
    deprecation_reason: ?[]const u8 = null,
};
```

## SDL Export

### toSDL

```zig
pub fn toSDL(self: *Schema, allocator: std.mem.Allocator) ![]const u8
```

Export schema as SDL string.

**Example:**

```zig
const sdl = try schema.toSDL(allocator);
defer allocator.free(sdl);
std.debug.print("{s}\n", .{sdl});
```

## Scalar Types

Built-in scalar types:

| Type | Description |
|------|-------------|
| `ID` | Unique identifier |
| `String` | UTF-8 string |
| `Int` | 32-bit integer |
| `Float` | 64-bit float |
| `Boolean` | true/false |
| `DateTime` | ISO 8601 datetime |
| `Date` | ISO 8601 date |
| `Time` | ISO 8601 time |
| `JSON` | Arbitrary JSON |
| `UUID` | UUID v4 |
| `Email` | Email address |
| `URL` | URL/URI |
| `IPv4` | IPv4 address |
| `IPv6` | IPv6 address |
| `Phone` | Phone number |
| `BigInt` | Large integer |
| `Decimal` | Decimal number |
| `Upload` | File upload |
| `Bytes` | Binary data |

## See Also

- [GraphQL Guide](/guide/graphql-schema)
- [GraphQL API](/api/graphql)
