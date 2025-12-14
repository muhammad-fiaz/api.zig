//! Zig API Framework - Complete Example
//!
//! Demonstrates framework features: HTML pages, static files, templates,
//! path/query parameters, JSON handling, and automatic OpenAPI generation.

const std = @import("std");
const api = @import("api");

// ============================================================================
// HTML Templates
// ============================================================================

const welcome_html =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\<meta charset="UTF-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\<title>Zig API Framework</title>
    \\<style>
    \\*{margin:0;padding:0;box-sizing:border-box}
    \\body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
    \\.card{background:#fff;border-radius:20px;padding:40px 50px;text-align:center;box-shadow:0 25px 50px -12px rgba(0,0,0,0.25);max-width:550px;width:100%}
    \\h1{color:#f7a41d;font-size:2.2rem;margin-bottom:8px;display:flex;align-items:center;justify-content:center;gap:10px}
    \\.subtitle{color:#666;font-size:1rem;margin-bottom:25px}
    \\.badge{display:inline-block;background:linear-gradient(135deg,#f7a41d,#ff8c00);color:#fff;padding:4px 12px;border-radius:20px;font-size:0.75rem;font-weight:600;margin-left:8px}
    \\.features{text-align:left;margin:25px 0;padding:20px;background:#f8f9fa;border-radius:12px}
    \\.features h3{color:#333;margin-bottom:12px;font-size:1rem}
    \\.features ul{list-style:none;display:grid;grid-template-columns:1fr 1fr;gap:8px}
    \\.features li{padding:6px 0;color:#555;font-size:0.9rem;display:flex;align-items:center;gap:8px}
    \\.features li::before{content:"-";font-size:0.8rem}
    \\.links{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;margin-top:20px}
    \\.links a{padding:12px 24px;background:linear-gradient(135deg,#f7a41d,#ff8c00);color:#fff;text-decoration:none;border-radius:8px;font-weight:500;font-size:0.9rem;transition:transform 0.2s,box-shadow 0.2s}
    \\.links a:hover{transform:translateY(-2px);box-shadow:0 10px 20px rgba(247,164,29,0.3)}
    \\.links a.secondary{background:#667eea}
    \\.links a.outline{background:transparent;border:2px solid #f7a41d;color:#f7a41d}
    \\@media(max-width:500px){.features ul{grid-template-columns:1fr}.card{padding:30px 25px}h1{font-size:1.8rem}}
    \\</style>
    \\</head>
    \\<body>
    \\<div class="card">
    \\<h1>Zig API Framework<span class="badge">v1.0</span></h1>
    \\<p class="subtitle">High Performance, Pure Zig</p>
    \\<div class="features">
    \\<h3>Features</h3>
    \\<ul>
    \\<li>Lightning-fast HTTP server</li>
    \\<li>Automatic OpenAPI 3.1</li>
    \\<li>Interactive Swagger UI</li>
    \\<li>ReDoc documentation</li>
    \\<li>Path parameters</li>
    \\<li>Query parameters</li>
    \\<li>JSON request/response</li>
    \\<li>HTML rendering</li>
    \\<li>Multi-threading ready</li>
    \\<li>Cross-platform</li>
    \\</ul>
    \\</div>
    \\<div class="links">
    \\<a href="/docs">Swagger UI</a>
    \\<a href="/redoc" class="secondary">ReDoc</a>
    \\<a href="/api/users" class="outline">Try API</a>
    \\</div>
    \\</div>
    \\</body>
    \\</html>
;

const about_html =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\<meta charset="UTF-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\<title>About - Zig API Framework</title>
    \\<style>
    \\*{margin:0;padding:0;box-sizing:border-box}
    \\body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;padding:40px 20px;max-width:800px;margin:0 auto;line-height:1.6;color:#333}
    \\h1{color:#f7a41d;margin-bottom:20px;display:flex;align-items:center;gap:10px}
    \\h2{color:#333;margin:30px 0 15px;border-bottom:2px solid #f7a41d;padding-bottom:8px}
    \\p{color:#555;margin-bottom:15px}
    \\code{background:#f4f4f4;padding:2px 8px;border-radius:4px;font-family:'Fira Code',monospace;font-size:0.9em}
    \\pre{background:#1e1e1e;color:#d4d4d4;padding:20px;border-radius:8px;overflow-x:auto;margin:15px 0}
    \\a{color:#667eea;text-decoration:none}
    \\a:hover{text-decoration:underline}
    \\.nav{margin-bottom:30px;padding:15px 0;border-bottom:1px solid #eee}
    \\.nav a{margin-right:20px;color:#f7a41d;font-weight:500}
    \\</style>
    \\</head>
    \\<body>
    \\<div class="nav">
    \\<a href="/">← Home</a>
    \\<a href="/docs">Swagger UI</a>
    \\<a href="/redoc">ReDoc</a>
    \\</div>
    \\<h1>Zig API Framework</h1>
    \\<p>A high-performance HTTP API framework for Zig.</p>
    \\<h2>Features</h2>
    \\<p>- <strong>Blazing Fast</strong> - Built with Zig for maximum performance</p>
    \\<p>- <strong>Automatic OpenAPI</strong> - Auto-generates OpenAPI 3.1 specification</p>
    \\<p>- <strong>Interactive Docs</strong> - Built-in Swagger UI and ReDoc</p>
    \\<p>- <strong>Type Safety</strong> - Compile-time route validation</p>
    \\<p>- <strong>Cross-Platform</strong> - Windows, Linux, macOS support</p>
    \\<h2>Quick Example</h2>
    \\<pre>const api = @import("api");
    \\
    \\fn hello() api.Response {
    \\    return api.Response.json(.{ .message = "Hello!" });
    \\}
    \\
    \\pub fn main() !void {
    \\    var app = try api.App.init(allocator, .{});
    \\    try app.get("/hello", hello);
    \\    try app.run(.{ .port = 8000 });
    \\}</pre>
    \\</body>
    \\</html>
;

// ============================================================================
// Route Handlers
// ============================================================================

/// Welcome page handler.
fn welcomePage() api.Response {
    return api.Response.html(welcome_html);
}

/// About page handler.
fn aboutPage() api.Response {
    return api.Response.html(about_html);
}

/// Health check endpoint.
fn healthCheck() api.Response {
    return api.Response.jsonRaw(
        \\{"status":"healthy","service":"Zig API Framework","version":"1.0.0"}
    );
}

/// Root API info endpoint.
fn rootInfo() api.Response {
    return api.Response.jsonRaw(
        \\{"message":"Welcome to Zig API Framework","docs":"/docs","redoc":"/redoc"}
    );
}

/// List users with query parameters.
fn listUsers(ctx: *api.Context) api.Response {
    const page = ctx.queryAsOr(u32, "page", 1);
    const limit = ctx.queryAsOr(u32, "limit", 10);
    const search = ctx.queryOr("search", "");

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"users":[{{"id":1,"name":"Alice"}},{{"id":2,"name":"Bob"}}],"page":{d},"limit":{d},"search":"{s}"}}
    , .{ page, limit, search }) catch return api.Response.jsonRaw(
        \\{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}
    );
    return api.Response.jsonRaw(json_response);
}

/// Get user by ID.
fn getUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"detail\":\"Missing ID\"}");
    const id = std.fmt.parseInt(u32, id_str, 10) catch return api.Response.err(.bad_request, "{\"detail\":\"Invalid ID\"}");

    if (id > 100) return api.Response.err(.not_found, "{\"detail\":\"User not found\"}");

    var buf: [128]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"id\":{d},\"name\":\"User {d}\",\"email\":\"user{d}@example.com\"}}", .{ id, id, id }) catch
        return api.Response.err(.internal_server_error, "{\"detail\":\"Format error\"}");
    return api.Response.jsonRaw(json_response);
}

/// Create a new user.
fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();
    if (body.len == 0) return api.Response.err(.bad_request, "{\"detail\":\"Request body required\"}");
    return api.Response.jsonRaw("{\"id\":3,\"name\":\"NewUser\",\"message\":\"User created successfully\"}").setStatus(.created);
}

/// Update user by ID
fn updateUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"detail\":\"Missing ID\"}");
    _ = std.fmt.parseInt(u32, id_str, 10) catch return api.Response.err(.bad_request, "{\"detail\":\"Invalid ID\"}");
    const body = ctx.body();
    if (body.len == 0) return api.Response.err(.bad_request, "{\"detail\":\"Request body required\"}");
    return api.Response.jsonRaw("{\"message\":\"User updated successfully\"}");
}

/// Delete user by ID
fn deleteUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"detail\":\"Missing ID\"}");
    const id = std.fmt.parseInt(u32, id_str, 10) catch return api.Response.err(.bad_request, "{\"detail\":\"Invalid ID\"}");
    if (id > 100) return api.Response.err(.not_found, "{\"detail\":\"User not found\"}");
    return api.Response.init().setStatus(.no_content);
}

/// Get product by ID - Path parameter
fn getProduct(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"detail\":\"Missing product ID\"}");
    var buf: [128]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"id\":\"{s}\",\"name\":\"Product {s}\",\"price\":99.99,\"in_stock\":true}}", .{ id, id }) catch
        return api.Response.err(.internal_server_error, "{\"detail\":\"Format error\"}");
    return api.Response.jsonRaw(json_response);
}

/// Get product review - Multiple path parameters
fn getProductReview(ctx: *api.Context) api.Response {
    const product_id = ctx.param("product_id") orelse return api.Response.err(.bad_request, "{\"detail\":\"Missing product ID\"}");
    const review_id = ctx.param("review_id") orelse return api.Response.err(.bad_request, "{\"detail\":\"Missing review ID\"}");
    var buf: [192]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"product_id\":\"{s}\",\"review_id\":\"{s}\",\"rating\":5,\"comment\":\"Excellent product!\"}}", .{ product_id, review_id }) catch
        return api.Response.err(.internal_server_error, "{\"detail\":\"Format error\"}");
    return api.Response.jsonRaw(json_response);
}

/// Greeting endpoint - Path parameter with default
fn greet(ctx: *api.Context) api.Response {
    const name = ctx.param("name") orelse "World";
    var buf: [64]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"message\":\"Hello, {s}!\"}}", .{name}) catch
        return api.Response.text("Hello!");
    return api.Response.jsonRaw(json_response);
}

/// Items endpoint - Query parameters demo
fn listItems(ctx: *api.Context) api.Response {
    const skip = ctx.queryAsOr(u32, "skip", 0);
    const limit = ctx.queryAsOr(u32, "limit", 10);

    var buf: [128]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"items\":[\"item1\",\"item2\",\"item3\"],\"skip\":{d},\"limit\":{d}}}", .{ skip, limit }) catch
        return api.Response.jsonRaw("{\"items\":[]}");
    return api.Response.jsonRaw(json_response);
}

/// Redirect to home page.
fn redirectToHome() api.Response {
    return api.Response.redirect("/");
}

// ============================================================================
// Main Application
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("  Zig API Framework\n", .{});
    std.debug.print("\n", .{});

    var app = try api.App.init(allocator, .{
        .title = "Zig API Framework",
        .version = "1.0.0",
        .description = "High-performance API framework for Zig with HTMLResponse, StaticFiles, Templates, path/query parameters, JSON handling, and automatic OpenAPI generation",
    });
    defer app.deinit();

    // HTML Pages
    // ========================================
    try app.get("/", welcomePage);
    try app.get("/home", welcomePage);
    try app.get("/about", aboutPage);

    // API Info & Health
    // ========================================
    try app.get("/api", rootInfo);
    try app.get("/health", healthCheck);

    // ========================================
    // Users REST API (Full CRUD)
    // ========================================
    try app.get("/api/users", listUsers); // List with query params
    try app.get("/api/users/{id}", getUser); // Get by ID (path param)
    try app.post("/api/users", createUser); // Create (request body)
    try app.put("/api/users/{id}", updateUser); // Update (path + body)
    try app.delete("/api/users/{id}", deleteUser); // Delete (path param)

    // ========================================
    // Products API (Multiple path parameters)
    // ========================================
    try app.get("/api/products/{id}", getProduct);
    try app.get("/api/products/{product_id}/reviews/{review_id}", getProductReview);

    // ========================================
    // Items API (Query parameters demo)
    // ========================================
    try app.get("/api/items", listItems);

    // ========================================
    // Greeting (Path parameter with name)
    // ========================================
    try app.get("/greet/{name}", greet);

    // ========================================
    // Redirect Example
    // ========================================
    try app.get("/old-home", redirectToHome);

    std.debug.print("  Starting server...\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  Features:\n", .{});
    std.debug.print("  - HTMLResponse: /, /about\n", .{});
    std.debug.print("  - JSONResponse: /api/users, /api/products\n", .{});
    std.debug.print("  - Path params:  /api/users/{{id}}, /greet/{{name}}\n", .{});
    std.debug.print("  - Query params: /api/users?page=1&limit=10\n", .{});
    std.debug.print("  - OpenAPI docs: /docs (Swagger UI)\n", .{});
    std.debug.print("  - ReDoc:        /redoc\n", .{});
    std.debug.print("\n", .{});

    try app.run(.{
        .port = 8000,
        .num_threads = 0,
        .auto_port = true,
    });
}

// ============================================================================
// Tests (run with: zig build test)
// ============================================================================

test "HTMLResponse - welcome page" {
    const resp = welcomePage();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "Zig API Framework") != null);
}

test "HTMLResponse - about page" {
    const resp = aboutPage();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
}

test "JSONResponse - health check" {
    const resp = healthCheck();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "healthy") != null);
}

test "JSONResponse - root info" {
    const resp = rootInfo();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "docs") != null);
}

test "RedirectResponse - redirect to home" {
    const resp = redirectToHome();
    try std.testing.expectEqual(api.StatusCode.found, resp.status);
}
