# GraphQL Resolvers API

API reference for GraphQL resolver implementation in api.zig.

## Executor

### Executor.init

```zig
pub fn init(allocator: std.mem.Allocator, schema: *Schema) Executor
```

Create a new GraphQL executor.

**Example:**

```zig
var executor = api.graphql.Executor.init(allocator, &schema);
```

### registerResolver

```zig
pub fn registerResolver(
    self: *Executor,
    type_name: []const u8,
    field_name: []const u8,
    resolver: ResolverFn,
) !void
```

Register a field resolver.

**Example:**

```zig
try executor.registerResolver("Query", "users", usersResolver);
try executor.registerResolver("Query", "user", userResolver);
try executor.registerResolver("User", "posts", userPostsResolver);
```

### execute

```zig
pub fn execute(
    self: *Executor,
    query: []const u8,
    variables: ?std.StringHashMap(Value),
    context: anytype,
) !ExecutionResult
```

Execute a GraphQL query.

**Example:**

```zig
const result = try executor.execute(
    "query { users { id name } }",
    null,
    &resolver_context,
);
```

## Resolver Function Types

### ResolverFn

```zig
pub const ResolverFn = *const fn (
    ctx: *anyopaque,
    args: ArgumentMap,
) anyerror!Value;
```

Standard resolver function type.

### FieldResolverFn

```zig
pub const FieldResolverFn = *const fn (
    ctx: *anyopaque,
    parent: Value,
    args: ArgumentMap,
) anyerror!Value;
```

Field resolver with parent value.

### SubscriptionResolverFn

```zig
pub const SubscriptionResolverFn = *const fn (
    ctx: *anyopaque,
    args: ArgumentMap,
) anyerror!AsyncIterator;
```

Subscription resolver returning async iterator.

## Value Type

### Value Union

```zig
pub const Value = union(enum) {
    null: void,
    int: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    list: []const Value,
    object: std.StringHashMap(Value),
    enum_value: []const u8,
    variable: []const u8,
};
```

### Value Methods

```zig
// Get as specific type
pub fn getString(self: Value) ?[]const u8
pub fn getInt(self: Value) ?i64
pub fn getFloat(self: Value) ?f64
pub fn getBool(self: Value) ?bool
pub fn getList(self: Value) ?[]const Value
pub fn getObject(self: Value) ?std.StringHashMap(Value)

// Create error value
pub fn error(message: []const u8, code: []const u8) Value
```

## ArgumentMap

### Methods

```zig
pub fn get(self: ArgumentMap, key: []const u8) ?Value
pub fn getString(self: ArgumentMap, key: []const u8) ?[]const u8
pub fn getInt(self: ArgumentMap, key: []const u8) ?i64
pub fn getFloat(self: ArgumentMap, key: []const u8) ?f64
pub fn getBool(self: ArgumentMap, key: []const u8) ?bool
pub fn getObject(self: ArgumentMap, key: []const u8) ?std.StringHashMap(Value)
```

## ExecutionResult

```zig
pub const ExecutionResult = struct {
    data: ?Value,
    errors: []const GraphQLError,
    
    pub fn toJson(self: ExecutionResult, allocator: std.mem.Allocator) ![]const u8
};
```

## GraphQLError

```zig
pub const GraphQLError = struct {
    message: []const u8,
    locations: []const Location = &.{},
    path: []const PathSegment = &.{},
    extensions: ?std.StringHashMap(Value) = null,
};

pub const Location = struct {
    line: u32,
    column: u32,
};

pub const PathSegment = union(enum) {
    field: []const u8,
    index: u32,
};
```

## DataLoader

Batch loading to prevent N+1 queries.

### DataLoader.init

```zig
pub fn init(
    allocator: std.mem.Allocator,
    batch_fn: BatchFn,
) DataLoader
```

### load

```zig
pub fn load(self: *DataLoader, key: K) !V
```

Load a single value (batched automatically).

### loadMany

```zig
pub fn loadMany(self: *DataLoader, keys: []const K) ![]V
```

Load multiple values.

**Example:**

```zig
const UserLoader = api.graphql.DataLoader([]const u8, User);

fn batchLoadUsers(keys: []const []const u8) ![]User {
    return db.getUsersByIds(keys);
}

var loader = UserLoader.init(allocator, batchLoadUsers);
const user = try loader.load("user-123");
```

## Resolver Context

Create a custom context struct:

```zig
const ResolverContext = struct {
    allocator: std.mem.Allocator,
    db: *Database,
    user: ?*AuthenticatedUser,
    loaders: struct {
        users: *UserLoader,
        posts: *PostLoader,
    },
};
```

## Example Resolvers

### Query Resolver

```zig
fn usersResolver(ctx_ptr: *anyopaque, args: ArgumentMap) !Value {
    const ctx = @ptrCast(*ResolverContext, ctx_ptr);
    _ = args;
    
    const users = try ctx.db.getAllUsers();
    var list = std.ArrayList(Value).init(ctx.allocator);
    
    for (users) |user| {
        var obj = std.StringHashMap(Value).init(ctx.allocator);
        try obj.put("id", .{ .string = user.id });
        try obj.put("name", .{ .string = user.name });
        try list.append(.{ .object = obj });
    }
    
    return .{ .list = list.items };
}
```

### Field Resolver

```zig
fn userPostsResolver(ctx_ptr: *anyopaque, parent: Value, args: ArgumentMap) !Value {
    const ctx = @ptrCast(*ResolverContext, ctx_ptr);
    const user_id = parent.getObject().?.get("id").?.string;
    const limit = args.getInt("limit") orelse 10;
    
    const posts = try ctx.loaders.posts.load(user_id);
    // ... convert to Value
}
```

### Mutation Resolver

```zig
fn createUserResolver(ctx_ptr: *anyopaque, args: ArgumentMap) !Value {
    const ctx = @ptrCast(*ResolverContext, ctx_ptr);
    const input = args.getObject("input") orelse return Value.error("Missing input", "BAD_REQUEST");
    
    const name = input.getString("name") orelse return Value.error("Missing name", "BAD_REQUEST");
    const email = input.getString("email") orelse return Value.error("Missing email", "BAD_REQUEST");
    
    const user = try ctx.db.createUser(.{ .name = name, .email = email });
    // ... convert to Value
}
```

## See Also

- [GraphQL Resolvers Guide](/guide/graphql-resolvers)
- [GraphQL API](/api/graphql)
