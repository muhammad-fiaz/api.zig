const std = @import("std");
const api = @import("api");

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
    role: UserRole,
    created_at: i64,
};

const UserRole = enum {
    ADMIN,
    MODERATOR,
    USER,
    GUEST,
};

const Post = struct {
    id: u32,
    title: []const u8,
    content: []const u8,
    author_id: u32,
    status: PostStatus,
    created_at: i64,
};

const PostStatus = enum {
    DRAFT,
    PUBLISHED,
    ARCHIVED,
};

const sample_users = [_]User{
    .{ .id = 1, .name = "Alice", .email = "alice@example.com", .role = .ADMIN, .created_at = 1702656000 },
    .{ .id = 2, .name = "Bob", .email = "bob@example.com", .role = .USER, .created_at = 1702656100 },
    .{ .id = 3, .name = "Charlie", .email = "charlie@example.com", .role = .MODERATOR, .created_at = 1702656200 },
};

const sample_posts = [_]Post{
    .{ .id = 1, .title = "Getting Started with Zig", .content = "Zig is a systems programming language...", .author_id = 1, .status = .PUBLISHED, .created_at = 1702656300 },
    .{ .id = 2, .title = "GraphQL Best Practices", .content = "Learn how to design GraphQL schemas...", .author_id = 2, .status = .PUBLISHED, .created_at = 1702656400 },
    .{ .id = 3, .title = "Draft Post", .content = "Work in progress...", .author_id = 1, .status = .DRAFT, .created_at = 1702656500 },
};

fn setupSchema(allocator: std.mem.Allocator) !api.graphql.Schema {
    var schema = api.graphql.Schema.init(allocator);

    try schema.addEnumType("UserRole", &.{
        .{ .name = "ADMIN", .description = "Full system access" },
        .{ .name = "MODERATOR", .description = "Content moderation access" },
        .{ .name = "USER", .description = "Standard user" },
        .{ .name = "GUEST", .description = "Read-only access" },
    }, "User permission roles");

    try schema.addEnumType("PostStatus", &.{
        .{ .name = "DRAFT", .description = "Not yet published" },
        .{ .name = "PUBLISHED", .description = "Publicly visible" },
        .{ .name = "ARCHIVED", .description = "No longer active" },
    }, "Post publication status");

    try schema.addObjectType(.{
        .name = "User",
        .description = "A user in the system",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "name", .type_name = "String", .is_non_null = true },
            .{ .name = "email", .type_name = "Email", .is_non_null = true },
            .{ .name = "role", .type_name = "UserRole", .is_non_null = true },
            .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
            .{ .name = "posts", .type_name = "Post", .is_list = true, .description = "Posts authored by this user" },
        },
    });

    try schema.addObjectType(.{
        .name = "Post",
        .description = "A blog post",
        .fields = &.{
            .{ .name = "id", .type_name = "ID", .is_non_null = true },
            .{ .name = "title", .type_name = "String", .is_non_null = true },
            .{ .name = "content", .type_name = "String" },
            .{ .name = "status", .type_name = "PostStatus", .is_non_null = true },
            .{ .name = "author", .type_name = "User", .is_non_null = true },
            .{ .name = "createdAt", .type_name = "DateTime", .is_non_null = true },
        },
    });

    try schema.addInputType("CreateUserInput", &.{
        .{ .name = "name", .type_name = "String", .is_non_null = true },
        .{ .name = "email", .type_name = "Email", .is_non_null = true },
        .{ .name = "role", .type_name = "UserRole", .default_value = "USER" },
    }, "Input for creating a new user");

    try schema.addInputType("CreatePostInput", &.{
        .{ .name = "title", .type_name = "String", .is_non_null = true },
        .{ .name = "content", .type_name = "String" },
        .{ .name = "authorId", .type_name = "ID", .is_non_null = true },
    }, "Input for creating a new post");

    try schema.addInputType("UpdatePostInput", &.{
        .{ .name = "title", .type_name = "String" },
        .{ .name = "content", .type_name = "String" },
        .{ .name = "status", .type_name = "PostStatus" },
    }, "Input for updating a post");

    try schema.setQueryType(.{
        .name = "Query",
        .description = "Root query type",
        .fields = &.{
            .{ .name = "users", .type_name = "User", .is_list = true, .is_non_null = true, .description = "Get all users" },
            .{ .name = "user", .type_name = "User", .args = &.{.{ .name = "id", .type_name = "ID", .is_non_null = true }}, .description = "Get a user by ID" },
            .{ .name = "posts", .type_name = "Post", .is_list = true, .is_non_null = true, .args = &.{ .{ .name = "status", .type_name = "PostStatus" }, .{ .name = "limit", .type_name = "Int", .default_value = "10" } }, .description = "Get all posts with optional filtering" },
            .{ .name = "post", .type_name = "Post", .args = &.{.{ .name = "id", .type_name = "ID", .is_non_null = true }}, .description = "Get a post by ID" },
            .{ .name = "searchPosts", .type_name = "Post", .is_list = true, .args = &.{.{ .name = "query", .type_name = "String", .is_non_null = true }}, .description = "Search posts by title or content" },
        },
    });

    try schema.setMutationType(.{
        .name = "Mutation",
        .description = "Root mutation type",
        .fields = &.{
            .{ .name = "createUser", .type_name = "User", .args = &.{.{ .name = "input", .type_name = "CreateUserInput", .is_non_null = true }}, .description = "Create a new user" },
            .{ .name = "deleteUser", .type_name = "Boolean", .is_non_null = true, .args = &.{.{ .name = "id", .type_name = "ID", .is_non_null = true }}, .description = "Delete a user by ID" },
            .{ .name = "createPost", .type_name = "Post", .args = &.{.{ .name = "input", .type_name = "CreatePostInput", .is_non_null = true }}, .description = "Create a new post" },
            .{ .name = "updatePost", .type_name = "Post", .args = &.{ .{ .name = "id", .type_name = "ID", .is_non_null = true }, .{ .name = "input", .type_name = "UpdatePostInput", .is_non_null = true } }, .description = "Update an existing post" },
            .{ .name = "publishPost", .type_name = "Post", .args = &.{.{ .name = "id", .type_name = "ID", .is_non_null = true }}, .description = "Publish a draft post" },
            .{ .name = "deletePost", .type_name = "Boolean", .is_non_null = true, .args = &.{.{ .name = "id", .type_name = "ID", .is_non_null = true }}, .description = "Delete a post by ID" },
        },
    });

    try schema.setSubscriptionType(.{
        .name = "Subscription",
        .description = "Root subscription type for real-time updates",
        .fields = &.{
            .{ .name = "userCreated", .type_name = "User", .is_non_null = true, .description = "Subscribe to new user creations" },
            .{ .name = "postPublished", .type_name = "Post", .is_non_null = true, .description = "Subscribe to newly published posts" },
            .{ .name = "postUpdated", .type_name = "Post", .is_non_null = true, .args = &.{.{ .name = "postId", .type_name = "ID" }}, .description = "Subscribe to post updates" },
        },
    });

    return schema;
}

const welcome_html =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\<meta charset="UTF-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\<title>GraphQL API</title>
    \\<style>
    \\*{margin:0;padding:0;box-sizing:border-box}
    \\body{font-family:system-ui,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
    \\.card{background:#fff;border-radius:16px;padding:40px;text-align:center;box-shadow:0 20px 40px rgba(0,0,0,0.2);max-width:600px;width:100%}
    \\h1{color:#333;font-size:2rem;margin-bottom:8px}
    \\.subtitle{color:#666;margin-bottom:24px}
    \\.links{display:flex;gap:12px;justify-content:center;flex-wrap:wrap}
    \\.links a{padding:12px 24px;background:#667eea;color:#fff;text-decoration:none;border-radius:8px;font-weight:500;transition:transform 0.2s}
    \\.links a:hover{transform:translateY(-2px)}
    \\.links a.alt{background:#764ba2}
    \\</style>
    \\</head>
    \\<body>
    \\<div class="card">
    \\<h1>GraphQL API</h1>
    \\<p class="subtitle">Full-featured GraphQL Server</p>
    \\<div class="links">
    \\<a href="/graphql/graphiql">GraphiQL</a>
    \\<a href="/graphql/playground" class="alt">Playground</a>
    \\<a href="/graphql/sandbox">Apollo Sandbox</a>
    \\<a href="/graphql/voyager" class="alt">Voyager</a>
    \\</div>
    \\</div>
    \\</body>
    \\</html>
;

fn welcomePage() api.Response {
    return api.Response.html(welcome_html);
}

fn healthCheck() api.Response {
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

    try app.enableGraphQL(&schema, .{
        .schema = &schema,
        .path = "/graphql",
        .graphiql_path = "/graphql/graphiql",
        .playground_path = "/graphql/playground",
        .apollo_sandbox_path = "/graphql/sandbox",
        .altair_path = "/graphql/altair",
        .voyager_path = "/graphql/voyager",
        .enable_introspection = true,
        .enable_playground = true,
        .max_depth = 15,
        .max_complexity = 1000,
        .enable_batching = true,
        .max_batch_size = 10,
        .enable_tracing = true,
        .mask_errors = false,
        .enable_caching = true,
        .cache_ttl_ms = 60000,
        .enable_cors = true,
        .enable_subscriptions = true,
        .ui_config = .{
            .theme = .dark,
            .title = "GraphQL Explorer",
            .show_docs = true,
            .show_history = true,
            .enable_persistence = true,
            .code_completion = true,
            .default_query =
            \\query GetUsers {
            \\  users {
            \\    id
            \\    name
            \\    email
            \\    role
            \\  }
            \\}
            ,
        },
    });

    try app.get("/", welcomePage);
    try app.get("/health", healthCheck);

    const cors = api.middleware.cors(.{
        .allowed_origins = &.{"*"},
        .allowed_methods = &.{ "GET", "POST", "OPTIONS" },
        .allowed_headers = &.{ "Content-Type", "Authorization" },
    });
    try app.use(cors.handle);

    std.debug.print("GraphQL API running at http://127.0.0.1:8080\n", .{});
    std.debug.print("  GraphiQL:   http://127.0.0.1:8080/graphql/graphiql\n", .{});
    std.debug.print("  Playground: http://127.0.0.1:8080/graphql/playground\n", .{});

    try app.run(.{ .port = 8080, .num_threads = 4 });
}
