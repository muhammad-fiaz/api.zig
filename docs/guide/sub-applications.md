# Sub-Applications

Organize large applications into modular routers with path prefixes and tag groupings.

## Router Composition

```zig
// routers/users.zig
const api = @import("api");

pub fn createRouter(allocator: std.mem.Allocator) !api.Router.Router {
    var router = api.Router.Router.init(allocator);
    
    try router.addRoute(api.Router.Router.register(.GET, "/", listUsers));
    try router.addRoute(api.Router.Router.register(.GET, "/{id}", getUser));
    try router.addRoute(api.Router.Router.register(.POST, "/", createUser));
    try router.addRoute(api.Router.Router.register(.PUT, "/{id}", updateUser));
    try router.addRoute(api.Router.Router.register(.DELETE, "/{id}", deleteUser));
    
    return router;
}
```

## Mounting Routers

```zig
// main.zig
const users = @import("routers/users.zig");
const products = @import("routers/products.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var app = try api.App.init(allocator, .{
        .title = "E-Commerce API",
        .version = "1.0.0",
    });
    defer app.deinit();
    
    var users_router = try users.createRouter(allocator);
    var products_router = try products.createRouter(allocator);
    
    try app.include_router(&users_router, "/api/v1/users", &.{"Users"});
    try app.include_router(&products_router, "/api/v1/products", &.{"Products"});
    
    try app.run(.{ .port = 8080 });
}
```

## OpenAPI Integration

Routes from included routers automatically appear in the generated OpenAPI specification with the applied prefix and tags.

## Versioned APIs

```zig
try app.include_router(&v1_router, "/api/v1", &.{"v1"});
try app.include_router(&v2_router, "/api/v2", &.{"v2"});
```
