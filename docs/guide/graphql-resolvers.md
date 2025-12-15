# GraphQL Resolvers

This guide covers implementing resolvers for GraphQL queries, mutations, and subscriptions in api.zig.

## Overview

Resolvers are functions that return data for GraphQL fields. They connect your schema to your data sources.

## Basic Resolver

```zig
const std = @import("std");
const api = @import("api");

// Define resolver context
const ResolverContext = struct {
    allocator: std.mem.Allocator,
    db: *Database,
    user: ?*User,
};

// Simple resolver
fn usersResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    _ = args;
    const users = try ctx.db.getAllUsers();
    return try userListToValue(ctx.allocator, users);
}

// Resolver with arguments
fn userResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const id = args.get("id") orelse return .{ .null = {} };
    const user = try ctx.db.getUserById(id.string) orelse return .{ .null = {} };
    return try userToValue(ctx.allocator, user);
}
```

## Registering Resolvers

```zig
var executor = api.graphql.Executor.init(allocator, &schema);

// Register field resolvers
try executor.registerResolver("Query", "users", usersResolver);
try executor.registerResolver("Query", "user", userResolver);
try executor.registerResolver("Mutation", "createUser", createUserResolver);
try executor.registerResolver("User", "posts", userPostsResolver);
```

## Query Resolvers

### List Resolver

```zig
fn usersResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const limit = args.getInt("limit") orelse 10;
    const offset = args.getInt("offset") orelse 0;
    
    const users = try ctx.db.getUsers(.{
        .limit = @intCast(limit),
        .offset = @intCast(offset),
    });
    
    var list = std.ArrayList(api.graphql.Value).init(ctx.allocator);
    for (users) |user| {
        try list.append(try userToValue(ctx.allocator, user));
    }
    
    return .{ .list = list.items };
}
```

### Single Item Resolver

```zig
fn userResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const id_val = args.get("id") orelse return .{ .null = {} };
    const id = switch (id_val) {
        .string => |s| s,
        .int => |i| try std.fmt.allocPrint(ctx.allocator, "{d}", .{i}),
        else => return .{ .null = {} },
    };
    
    const user = ctx.db.getUserById(id) catch return .{ .null = {} };
    if (user) |u| {
        return try userToValue(ctx.allocator, u);
    }
    return .{ .null = {} };
}
```

### Search Resolver

```zig
fn searchUsersResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const query = args.getString("query") orelse return .{ .list = &.{} };
    const limit = args.getInt("limit") orelse 10;
    
    const results = try ctx.db.searchUsers(query, @intCast(limit));
    
    var list = std.ArrayList(api.graphql.Value).init(ctx.allocator);
    for (results) |user| {
        try list.append(try userToValue(ctx.allocator, user));
    }
    
    return .{ .list = list.items };
}
```

## Mutation Resolvers

### Create Resolver

```zig
fn createUserResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const input = args.getObject("input") orelse return error.MissingInput;
    
    const name = input.getString("name") orelse return error.MissingName;
    const email = input.getString("email") orelse return error.MissingEmail;
    const role = input.getString("role") orelse "USER";
    
    const user = try ctx.db.createUser(.{
        .name = name,
        .email = email,
        .role = role,
    });
    
    return try userToValue(ctx.allocator, user);
}
```

### Update Resolver

```zig
fn updateUserResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const id = args.getString("id") orelse return error.MissingId;
    const input = args.getObject("input") orelse return error.MissingInput;
    
    var updates = std.StringHashMap([]const u8).init(ctx.allocator);
    
    if (input.getString("name")) |name| {
        try updates.put("name", name);
    }
    if (input.getString("email")) |email| {
        try updates.put("email", email);
    }
    
    const user = try ctx.db.updateUser(id, updates);
    return try userToValue(ctx.allocator, user);
}
```

### Delete Resolver

```zig
fn deleteUserResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const id = args.getString("id") orelse return error.MissingId;
    
    const deleted = try ctx.db.deleteUser(id);
    return .{ .boolean = deleted };
}
```

## Field Resolvers

### Nested Object Resolver

```zig
fn userPostsResolver(ctx: *ResolverContext, parent: api.graphql.Value, args: anytype) !api.graphql.Value {
    const user_id = parent.getObject().?.getString("id") orelse return .{ .list = &.{} };
    const limit = args.getInt("limit") orelse 10;
    
    const posts = try ctx.db.getPostsByUserId(user_id, @intCast(limit));
    
    var list = std.ArrayList(api.graphql.Value).init(ctx.allocator);
    for (posts) |post| {
        try list.append(try postToValue(ctx.allocator, post));
    }
    
    return .{ .list = list.items };
}
```

### Computed Field Resolver

```zig
fn userFullNameResolver(ctx: *ResolverContext, parent: api.graphql.Value, args: anytype) !api.graphql.Value {
    _ = args;
    const obj = parent.getObject() orelse return .{ .null = {} };
    
    const first = obj.getString("firstName") orelse "";
    const last = obj.getString("lastName") orelse "";
    
    const full_name = try std.fmt.allocPrint(ctx.allocator, "{s} {s}", .{ first, last });
    return .{ .string = full_name };
}
```

## Subscription Resolvers

```zig
fn messageAddedResolver(ctx: *ResolverContext, args: anytype) !api.graphql.AsyncIterator {
    const channel_id = args.getString("channelId") orelse return error.MissingChannelId;
    
    return ctx.pubsub.subscribe("message_added", channel_id);
}

fn userStatusChangedResolver(ctx: *ResolverContext, args: anytype) !api.graphql.AsyncIterator {
    _ = args;
    return ctx.pubsub.subscribe("user_status_changed", null);
}
```

## Error Handling

### Returning Errors

```zig
fn userResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    const id = args.getString("id") orelse {
        return api.graphql.Value.error("Missing required argument: id", "MISSING_ARGUMENT");
    };
    
    const user = ctx.db.getUserById(id) catch |err| {
        return switch (err) {
            error.NotFound => api.graphql.Value.error("User not found", "NOT_FOUND"),
            error.DatabaseError => api.graphql.Value.error("Database error", "INTERNAL_ERROR"),
            else => error.UnexpectedError,
        };
    };
    
    return try userToValue(ctx.allocator, user);
}
```

### Authorization

```zig
fn adminOnlyResolver(ctx: *ResolverContext, args: anytype) !api.graphql.Value {
    // Check authentication
    const user = ctx.user orelse {
        return api.graphql.Value.error("Not authenticated", "UNAUTHENTICATED");
    };
    
    // Check authorization
    if (user.role != .ADMIN) {
        return api.graphql.Value.error("Admin access required", "FORBIDDEN");
    }
    
    // Proceed with resolver logic
    return try performAdminAction(ctx, args);
}
```

## Data Loaders

Prevent N+1 queries with data loaders:

```zig
const UserLoader = api.graphql.DataLoader([]const u8, User);

fn userPostsResolver(ctx: *ResolverContext, parent: api.graphql.Value, args: anytype) !api.graphql.Value {
    _ = args;
    const user_id = parent.getObject().?.getString("id") orelse return .{ .list = &.{} };
    
    // Batch load posts
    const posts = try ctx.post_loader.load(user_id);
    
    var list = std.ArrayList(api.graphql.Value).init(ctx.allocator);
    for (posts) |post| {
        try list.append(try postToValue(ctx.allocator, post));
    }
    
    return .{ .list = list.items };
}
```

## Value Conversion Helpers

```zig
fn userToValue(allocator: std.mem.Allocator, user: User) !api.graphql.Value {
    var obj = std.StringHashMap(api.graphql.Value).init(allocator);
    
    try obj.put("id", .{ .string = user.id });
    try obj.put("name", .{ .string = user.name });
    try obj.put("email", .{ .string = user.email });
    try obj.put("role", .{ .enum_value = @tagName(user.role) });
    try obj.put("createdAt", .{ .string = try formatDateTime(allocator, user.created_at) });
    
    return .{ .object = obj };
}

fn userListToValue(allocator: std.mem.Allocator, users: []const User) !api.graphql.Value {
    var list = std.ArrayList(api.graphql.Value).init(allocator);
    for (users) |user| {
        try list.append(try userToValue(allocator, user));
    }
    return .{ .list = list.items };
}
```

## See Also

- [GraphQL Guide](/guide/graphql)
- [GraphQL Schema](/guide/graphql-schema)
- [GraphQL API](/api/graphql)
