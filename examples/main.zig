//! Zig API Framework - Production Example
//!
//! Demonstrates all framework features: middleware, authentication, validation,
//! cookies, JSON handling, path/query parameters, and automatic OpenAPI generation.

const std = @import("std");
const api = @import("api");

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
    \\.card{background:#fff;border-radius:20px;padding:40px 50px;text-align:center;box-shadow:0 25px 50px -12px rgba(0,0,0,0.25);max-width:600px;width:100%}
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
    \\<p class="subtitle">Production-Ready, Pure Zig HTTP Framework</p>
    \\<div class="features">
    \\<h3>Production Features</h3>
    \\<ul>
    \\<li>Multi-threaded HTTP Server</li>
    \\<li>Automatic OpenAPI 3.1</li>
    \\<li>Authentication Middleware</li>
    \\<li>CORS with RFC 6454</li>
    \\<li>Rate Limiting</li>
    \\<li>Security Headers</li>
    \\<li>Cookie Management</li>
    \\<li>Input Validation</li>
    \\<li>JSON Request/Response</li>
    \\<li>Type-safe Extractors</li>
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

fn welcomePage() api.Response {
    return api.Response.html(welcome_html);
}

fn healthCheck() api.Response {
    return api.Response.jsonRaw(
        \\{"status":"healthy","service":"Zig API Framework","version":"1.0.0","timestamp":1702656000}
    );
}

fn rootInfo() api.Response {
    return api.Response.jsonRaw(
        \\{"message":"Welcome to Zig API Framework","docs":"/docs","redoc":"/redoc","health":"/health"}
    );
}

fn listUsers(ctx: *api.Context) api.Response {
    const page = ctx.queryAsOr(u32, "page", 1);
    const limit = ctx.queryAsOr(u32, "limit", 10);
    const search = ctx.queryOr("search", "");

    var buf: [512]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"users":[{{"id":1,"name":"Alice","email":"alice@example.com","role":"admin"}},{{"id":2,"name":"Bob","email":"bob@example.com","role":"user"}}],"pagination":{{"page":{d},"limit":{d},"total":100}},"filter":"{s}"}}
    , .{ page, limit, search }) catch return api.Response.jsonRaw(
        \\{"users":[],"error":"format_error"}
    );
    return api.Response.jsonRaw(json_response);
}

fn getUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"error\":\"missing_id\",\"message\":\"User ID is required\"}");
    const id = std.fmt.parseInt(u32, id_str, 10) catch return api.Response.err(.bad_request, "{\"error\":\"invalid_id\",\"message\":\"User ID must be a number\"}");

    if (id > 100) return api.Response.err(.not_found, "{\"error\":\"not_found\",\"message\":\"User not found\"}");

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"id":{d},"name":"User {d}","email":"user{d}@example.com","role":"user","created_at":"2024-01-15T10:30:00Z"}}
    , .{ id, id, id }) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();
    if (body.len == 0) return api.Response.err(.bad_request, "{\"error\":\"missing_body\",\"message\":\"Request body required\"}");

    if (body.len > 10000) return api.Response.err(.payload_too_large, "{\"error\":\"payload_too_large\",\"message\":\"Request body too large\"}");

    return api.Response.jsonRaw(
        \\{"id":3,"name":"NewUser","email":"newuser@example.com","message":"User created successfully"}
    ).setStatus(.created);
}

fn updateUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"error\":\"missing_id\"}");
    const id = std.fmt.parseInt(u32, id_str, 10) catch return api.Response.err(.bad_request, "{\"error\":\"invalid_id\"}");

    if (id > 100) return api.Response.err(.not_found, "{\"error\":\"not_found\"}");

    const body = ctx.body();
    if (body.len == 0) return api.Response.err(.bad_request, "{\"error\":\"missing_body\"}");

    var buf: [128]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"id":{d},"message":"User updated successfully"}}
    , .{id}) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn deleteUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"error\":\"missing_id\"}");
    const id = std.fmt.parseInt(u32, id_str, 10) catch return api.Response.err(.bad_request, "{\"error\":\"invalid_id\"}");

    if (id > 100) return api.Response.err(.not_found, "{\"error\":\"not_found\"}");

    return api.Response.init().setStatus(.no_content);
}

fn getProduct(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"error\":\"missing_product_id\"}");

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"id":"{s}","name":"Product {s}","price":99.99,"currency":"USD","in_stock":true,"category":"electronics"}}
    , .{ id, id }) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn getProductReview(ctx: *api.Context) api.Response {
    const product_id = ctx.param("product_id") orelse return api.Response.err(.bad_request, "{\"error\":\"missing_product_id\"}");
    const review_id = ctx.param("review_id") orelse return api.Response.err(.bad_request, "{\"error\":\"missing_review_id\"}");

    var buf: [320]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"product_id":"{s}","review_id":"{s}","rating":5,"title":"Great product!","comment":"Highly recommended.","author":"verified_buyer","verified":true}}
    , .{ product_id, review_id }) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn createOrder(ctx: *api.Context) api.Response {
    const body = ctx.body();
    if (body.len == 0) return api.Response.err(.bad_request, "{\"error\":\"missing_body\"}");

    return api.Response.jsonRaw(
        \\{"order_id":"ORD-2024-001","status":"pending","total":199.98,"currency":"USD","items":[{"product_id":"P001","quantity":2}]}
    ).setStatus(.created);
}

fn listOrders(ctx: *api.Context) api.Response {
    const status = ctx.queryOr("status", "all");
    const page = ctx.queryAsOr(u32, "page", 1);

    var buf: [512]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"orders":[{{"id":"ORD-001","status":"completed","total":99.99}},{{"id":"ORD-002","status":"pending","total":149.99}}],"filter":"{s}","page":{d}}}
    , .{ status, page }) catch return api.Response.jsonRaw("{\"orders\":[]}");
    return api.Response.jsonRaw(json_response);
}

fn greet(ctx: *api.Context) api.Response {
    const name = ctx.param("name") orelse "World";

    var buf: [128]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"message\":\"Hello, {s}!\",\"timestamp\":{d}}}", .{ name, std.time.timestamp() }) catch
        return api.Response.text("Hello!");
    return api.Response.jsonRaw(json_response);
}

fn listItems(ctx: *api.Context) api.Response {
    const skip = ctx.queryAsOr(u32, "skip", 0);
    const limit = ctx.queryAsOr(u32, "limit", 10);
    const category = ctx.queryOr("category", "all");

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"items":["item1","item2","item3"],"skip":{d},"limit":{d},"category":"{s}","total":50}}
    , .{ skip, limit, category }) catch return api.Response.jsonRaw("{\"items\":[]}");
    return api.Response.jsonRaw(json_response);
}

fn validateEmail(ctx: *api.Context) api.Response {
    const email = ctx.queryOr("email", "");
    if (email.len == 0) return api.Response.err(.bad_request, "{\"error\":\"missing_email\"}");

    const is_valid = api.validation.isEmail(email);

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"email":"{s}","valid":{s}}}
    , .{ email, if (is_valid) "true" else "false" }) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn validateUrl(ctx: *api.Context) api.Response {
    const url = ctx.queryOr("url", "");
    if (url.len == 0) return api.Response.err(.bad_request, "{\"error\":\"missing_url\"}");

    const is_valid = api.validation.isUrl(url);

    var buf: [512]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"url":"{s}","valid":{s}}}
    , .{ url, if (is_valid) "true" else "false" }) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn setCookie() api.Response {
    const cookie = api.Cookie.init("session", "abc123xyz")
        .setPath("/")
        .setHttpOnly(true)
        .setSecure(true)
        .setSameSite(.strict)
        .setMaxAge(3600);

    return api.Response.jsonRaw("{\"message\":\"Cookie set successfully\",\"cookie_name\":\"session\"}")
        .withCookie(cookie);
}

fn getCookieInfo(ctx: *api.Context) api.Response {
    const session = ctx.header("Cookie") orelse return api.Response.jsonRaw("{\"cookies\":null}");

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf, "{{\"cookies\":\"{s}\"}}", .{session}) catch
        return api.Response.jsonRaw("{\"cookies\":\"error\"}");
    return api.Response.jsonRaw(json_response);
}

fn serverStats() api.Response {
    return api.Response.jsonRaw(
        \\{"uptime_seconds":3600,"requests_total":10000,"requests_per_second":2.78,"memory_mb":128,"active_connections":42}
    );
}

fn echoRequest(ctx: *api.Context) api.Response {
    const method_str = ctx.method().toString();
    const path_str = ctx.path();
    const body_len = ctx.body().len;

    var buf: [256]u8 = undefined;
    const json_response = std.fmt.bufPrint(&buf,
        \\{{"method":"{s}","path":"{s}","body_length":{d},"timestamp":{d}}}
    , .{ method_str, path_str, body_len, std.time.timestamp() }) catch return api.Response.err(.internal_server_error, "{\"error\":\"internal\"}");
    return api.Response.jsonRaw(json_response);
}

fn redirectToHome() api.Response {
    return api.Response.redirect("/");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("  API.zig Framework v1.0.0\n", .{});
    std.debug.print("  Production-Ready HTTP Server\n", .{});
    std.debug.print("\n", .{});

    var app = try api.App.init(allocator, .{
        .title = "Zig API Framework",
        .version = "1.0.0",
        .description = "Production-ready HTTP API framework with middleware, authentication, validation, cookies, and OpenAPI generation",
    });
    defer app.deinit();

    try app.get("/", welcomePage);
    try app.get("/home", welcomePage);

    try app.get("/api", rootInfo);
    try app.get("/health", healthCheck);
    try app.get("/stats", serverStats);
    try app.get("/echo", echoRequest);
    try app.post("/echo", echoRequest);

    try app.get("/api/users", listUsers);
    try app.get("/api/users/{id}", getUser);
    try app.post("/api/users", createUser);
    try app.put("/api/users/{id}", updateUser);
    try app.delete("/api/users/{id}", deleteUser);

    try app.get("/api/products/{id}", getProduct);
    try app.get("/api/products/{product_id}/reviews/{review_id}", getProductReview);

    try app.get("/api/orders", listOrders);
    try app.post("/api/orders", createOrder);

    try app.get("/api/items", listItems);

    try app.get("/greet/{name}", greet);

    try app.get("/api/validate/email", validateEmail);
    try app.get("/api/validate/url", validateUrl);

    try app.get("/api/cookies/set", setCookie);
    try app.get("/api/cookies/get", getCookieInfo);

    try app.get("/old-home", redirectToHome);

    std.debug.print("  Endpoints:\n", .{});
    std.debug.print("  - GET  /              Welcome page\n", .{});
    std.debug.print("  - GET  /health        Health check\n", .{});
    std.debug.print("  - GET  /stats         Server statistics\n", .{});
    std.debug.print("  - GET  /api/users     List users\n", .{});
    std.debug.print("  - POST /api/users     Create user\n", .{});
    std.debug.print("  - GET  /api/users/:id Get user by ID\n", .{});
    std.debug.print("  - GET  /api/products  Products API\n", .{});
    std.debug.print("  - GET  /api/orders    Orders API\n", .{});
    std.debug.print("  - GET  /api/validate  Validation endpoints\n", .{});
    std.debug.print("  - GET  /docs          Swagger UI\n", .{});
    std.debug.print("  - GET  /redoc         ReDoc documentation\n", .{});
    std.debug.print("\n", .{});

    try app.run(.{
        .port = 8000,
        .num_threads = 0,
        .auto_port = true,
    });
}

test "welcome page returns HTML" {
    const resp = welcomePage();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "Zig API Framework") != null);
}

test "health check returns JSON" {
    const resp = healthCheck();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "healthy") != null);
}

test "root info returns JSON" {
    const resp = rootInfo();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "docs") != null);
}

test "server stats returns JSON" {
    const resp = serverStats();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(std.mem.indexOf(u8, resp.body, "uptime_seconds") != null);
}

test "redirect returns 302" {
    const resp = redirectToHome();
    try std.testing.expectEqual(api.StatusCode.found, resp.status);
}

test "set cookie returns with Set-Cookie header" {
    const resp = setCookie();
    try std.testing.expectEqual(api.StatusCode.ok, resp.status);
    try std.testing.expect(resp.headers.get("Set-Cookie") != null);
}
