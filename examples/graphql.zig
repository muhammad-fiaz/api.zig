const std = @import("std");
const api = @import("api");

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
    role: UserRole,
};

const UserRole = enum {
    ADMIN,
    USER,
    GUEST,
};

const sample_users = [_]User{
    .{ .id = 1, .name = "Alice", .email = "alice@example.com", .role = .ADMIN },
    .{ .id = 2, .name = "Bob", .email = "bob@example.com", .role = .USER },
    .{ .id = 3, .name = "Charlie", .email = "charlie@example.com", .role = .GUEST },
};

fn setupSchema(allocator: std.mem.Allocator) !api.graphql.Schema {
    var schema = api.graphql.Schema.init(allocator);

    try schema.addEnumType("UserRole", &.{
        .{ .name = "ADMIN", .description = "Administrator access" },
        .{ .name = "USER", .description = "Standard user" },
        .{ .name = "GUEST", .description = "Guest access" },
    }, "User permission roles");

    try schema.addObjectType(.{
        .name = "User",
        .description = "A user in the system",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "email", .type_name = "Email", .is_non_null = true },
            .{ .name = "role", .type_name = "UserRole", .is_non_null = true },
        },
    });

    try schema.setQueryType(.{
        .name = "Query",
        .description = "Root query type",
        .fields = &.{
            .{ .name = "users", .type_name = "User", .is_list = true, .is_non_null = true, .description = "Get all users" },
            .{ .name = "user", .type_name = "User", .args = &.{.{ .name = "id", .type_name = "ID", .is_non_null = true }}, .description = "Get user by ID" },
            .{ .name = "hello", .type_name = "String", .is_non_null = true, .description = "Say hello" },
        },
    });

    try schema.setMutationType(.{
        .name = "Mutation",
        .description = "Root mutation type",
        .fields = &.{
            .{ .name = "createUser", .type_name = "User", .args = &.{
                .{ .name = "name", .type_name = "String", .is_non_null = true },
                .{ .name = "email", .type_name = "Email", .is_non_null = true },
            }, .description = "Create a new user" },
        },
    });

    return schema;
}

// --- Simple resolvers for the example schema ---
fn resolve_hello(ctx: *api.Context, args: api.graphql.Arguments) anyerror!?api.graphql.Value {
    _ = ctx;
    _ = args;
    return api.graphql.Value{ .string = "Hello from api.zig!" };
}

fn resolve_users(ctx: *api.Context, args: api.graphql.Arguments) anyerror!?api.graphql.Value {
    _ = args;
    var list: std.ArrayListUnmanaged(api.graphql.Value) = .{};

    for (sample_users) |u| {
        const uid = @as(i64, u.id);
        var obj = std.StringHashMap(api.graphql.Value).init(ctx.allocator);
        try obj.put("id", api.graphql.Value{ .int = uid });
        try obj.put("name", api.graphql.Value{ .string = u.name });
        try obj.put("email", api.graphql.Value{ .string = u.email });
        const role_str = switch (u.role) {
            UserRole.ADMIN => "ADMIN",
            UserRole.USER => "USER",
            UserRole.GUEST => "GUEST",
        };
        try obj.put("role", api.graphql.Value{ .string = role_str });

        try list.append(ctx.allocator, api.graphql.Value{ .object = obj });
    }

    const slice = try list.toOwnedSlice(ctx.allocator);
    return api.graphql.Value{ .list = slice };
}

fn resolve_user(ctx: *api.Context, args: api.graphql.Arguments) anyerror!?api.graphql.Value {
    if (args.getInt("id")) |id| {
        for (sample_users) |u| {
            const uid = @as(i64, u.id);
            if (uid == id) {
                var obj = std.StringHashMap(api.graphql.Value).init(ctx.allocator);
                try obj.put("id", api.graphql.Value{ .int = uid });
                try obj.put("name", api.graphql.Value{ .string = u.name });
                try obj.put("email", api.graphql.Value{ .string = u.email });
                const role_str = switch (u.role) {
                    UserRole.ADMIN => "ADMIN",
                    UserRole.USER => "USER",
                    UserRole.GUEST => "GUEST",
                };
                try obj.put("role", api.graphql.Value{ .string = role_str });
                return api.graphql.Value{ .object = obj };
            }
        }
    }
    return api.graphql.Value{ .null = {} };
}

const welcome_html =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\<meta charset="UTF-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\<title>GraphQL API - api.zig</title>
    \\<style>
    \\*{margin:0;padding:0;box-sizing:border-box}
    \\body{font-family:system-ui,sans-serif;background:linear-gradient(135deg,#6366f1 0%,#8b5cf6 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
    \\.card{background:#fff;border-radius:16px;padding:40px;text-align:center;box-shadow:0 20px 40px rgba(0,0,0,0.2);max-width:500px;width:100%}
    \\h1{color:#333;font-size:2rem;margin-bottom:8px}
    \\.subtitle{color:#666;margin-bottom:24px}
    \\.section{margin-bottom:20px}
    \\.section-title{font-size:0.9rem;color:#999;margin-bottom:12px;text-transform:uppercase;letter-spacing:1px}
    \\.links{display:flex;gap:12px;justify-content:center;flex-wrap:wrap}
    \\.links a{padding:12px 24px;background:linear-gradient(135deg,#6366f1,#8b5cf6);color:#fff;text-decoration:none;border-radius:8px;font-weight:500;transition:transform 0.2s,box-shadow 0.2s}
    \\.links a:hover{transform:translateY(-2px);box-shadow:0 4px 12px rgba(99,102,241,0.5)}
    \\.links a.alt{background:linear-gradient(135deg,#10b981,#059669)}
    \\</style>
    \\</head>
    \\<body>
    \\<div class="card">
    \\<h1>⚡ GraphQL API</h1>
    \\<p class="subtitle">Powered by api.zig</p>
    \\<div class="section">
    \\<div class="section-title">GraphQL</div>
    \\<div class="links">
    \\<a href="/graphql/playground">GraphQL Playground</a>
    \\</div>
    \\</div>
    \\<div class="section">
    \\<div class="section-title">REST API</div>
    \\<div class="links">
    \\<a href="/docs" class="alt">Swagger</a>
    \\<a href="/redoc" class="alt">ReDoc</a>
    \\</div>
    \\</div>
    \\</div>
    \\</body>
    \\</html>
;

fn welcomePage(_: *api.Context) api.Response {
    return api.Response.html(welcome_html);
}

fn healthCheck(_: *api.Context) api.Response {
    return api.Response.jsonRaw(
        \\{"status":"healthy","service":"graphql-api"}
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "GraphQL API",
        .description = "GraphQL API with api.zig",
        .version = "1.0.0",
    });
    defer app.deinit();

    var schema = try setupSchema(allocator);
    defer schema.deinit();

    // Register simple resolvers so the example returns concrete data
    try schema.addResolver("Query", "hello", &resolve_hello);
    try schema.addResolver("Query", "users", &resolve_users);
    try schema.addResolver("Query", "user", &resolve_user);

    try app.enableGraphQL(&schema, .{
        .schema = &schema,
        .path = "/graphql",
        .playground_path = "/graphql/playground",
        .enable_introspection = true,
        .enable_playground = true,
        .enable_cors = true,
    });

    try app.get("/", welcomePage);
    try app.get("/health", healthCheck);

    std.debug.print("\n", .{});
    std.debug.print("  ⚡ GraphQL API running at http://127.0.0.1:8080\n", .{});
    std.debug.print("     Playground: http://127.0.0.1:8080/graphql/playground\n", .{});
    std.debug.print("     REST Docs:  http://127.0.0.1:8080/docs\n", .{});
    std.debug.print("\n", .{});

    try app.run(.{ .port = 8080, .num_threads = 4 });
}
