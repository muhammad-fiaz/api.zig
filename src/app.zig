//! Application Orchestrator
//!
//! Main application type for HTTP routing, middleware, OpenAPI generation, and server lifecycle.

const std = @import("std");
const http = @import("http.zig");
const Router = @import("router.zig");
const Server = @import("server.zig").Server;
const ServerConfig = @import("server.zig").ServerConfig;
const Response = @import("response.zig").Response;
const Request = @import("request.zig").Request;
const Context = @import("context.zig").Context;
const OpenAPI = @import("openapi.zig").OpenAPI;
const Logger = @import("logger.zig").Logger;
const json = @import("json.zig");

/// Application configuration.
pub const AppConfig = struct {
    title: []const u8 = "Zig API Framework",
    version: []const u8 = "1.0.0",
    description: ?[]const u8 = "High-performance API framework for Zig with automatic OpenAPI generation",
    debug: bool = false,
    docs_url: []const u8 = "/docs",
    redoc_url: []const u8 = "/redoc",
    openapi_url: []const u8 = "/openapi.json",
};

/// Server runtime configuration.
pub const RunConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8000,
    access_log: bool = true,
    num_threads: ?u8 = null,
    auto_port: bool = true,
};

/// Main application type.
pub const App = struct {
    allocator: std.mem.Allocator,
    config: AppConfig,
    router: Router.Router,
    openapi: OpenAPI,
    logger: *Logger,
    middleware: std.ArrayListUnmanaged(MiddlewareFn) = .{},

    /// Middleware function signature for request/response processing.
    pub const MiddlewareFn = *const fn (*Context, HandlerFn) Response;

    /// Route handler function signature.
    pub const HandlerFn = *const fn (*Context) Response;

    /// Initializes a new application instance with the provided configuration.
    /// Allocates resources for routing, logging, and OpenAPI generation.
    pub fn init(allocator: std.mem.Allocator, config: AppConfig) !App {
        const logger = try Logger.init(allocator);

        return .{
            .allocator = allocator,
            .config = config,
            .router = Router.Router.init(allocator),
            .openapi = OpenAPI.init(allocator, .{
                .title = config.title,
                .version = config.version,
                .description = config.description,
            }),
            .logger = logger,
            .middleware = .{},
        };
    }

    /// Initializes an application with default configuration values.
    pub fn initDefault(allocator: std.mem.Allocator) !App {
        return init(allocator, .{});
    }

    /// Releases all resources held by the application.
    pub fn deinit(self: *App) void {
        self.router.deinit();
        self.middleware.deinit(self.allocator);
        self.openapi.deinit();
        self.logger.deinit();
    }

    /// Registers a GET route handler for the specified path pattern.
    pub fn get(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.GET, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("GET", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a POST route handler for the specified path pattern.
    pub fn post(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.POST, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("POST", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a PUT route handler for the specified path pattern.
    pub fn put(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.PUT, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("PUT", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a DELETE route handler for the specified path pattern.
    pub fn delete(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.DELETE, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("DELETE", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a PATCH route handler for the specified path pattern.
    pub fn patch(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.PATCH, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("PATCH", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a route with an explicit HTTP method.
    pub fn addRoute(self: *App, comptime method: http.Method, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(method, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath(method.toString(), path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a route with full configuration options.
    pub fn route(self: *App, comptime config: Router.RouteConfig, handler: anytype) !void {
        const r = comptime Router.Router.route(config, handler);
        try self.router.addRoute(r);
        try self.openapi.addPath(config.method.toString(), config.path, r.summary, r.description, r.tags, r.deprecated);
    }

    /// Mounts a handler at a path prefix for serving static files or sub-applications.
    pub fn mount(self: *App, comptime path: []const u8, handler: *const fn (*Context) Response) !void {
        const r = Router.Route{
            .method = .GET,
            .path = path,
            .handler = handler,
            .segment_count = 0,
            .summary = "Static files",
            .description = "Serves static files from directory",
            .tags = &.{},
            .deprecated = false,
        };
        try self.router.addRoute(r);
    }

    /// Includes routes from an external module containing a routes declaration.
    pub fn include(self: *App, comptime routes_module: type) !void {
        if (@hasDecl(routes_module, "routes")) {
            inline for (routes_module.routes) |r| {
                try self.router.addRoute(r);
            }
        }
    }

    /// Adds a middleware function to the request processing pipeline.
    pub fn use(self: *App, middleware_fn: MiddlewareFn) !void {
        try self.middleware.append(self.allocator, middleware_fn);
    }

    /// Returns the generated OpenAPI JSON specification.
    pub fn getOpenAPISpec(self: *const App) ![]u8 {
        return self.openapi.toJson(self.allocator);
    }

    /// Starts the HTTP server with the provided runtime configuration.
    /// This method blocks until the server is stopped.
    pub fn run(self: *App, config: RunConfig) !void {
        const thread_count: u8 = config.num_threads orelse @min(std.Thread.getCpuCount() catch 4, 32);

        var server = try Server.init(self.allocator, &self.router, .{
            .address = config.host,
            .port = config.port,
            .enable_access_log = config.access_log,
            .num_threads = thread_count,
            .auto_port = config.auto_port,
        });
        defer server.deinit();

        const openapi_json = try self.openapi.toJson(self.allocator);
        defer self.allocator.free(openapi_json);
        server.setOpenApiJson(openapi_json);

        try server.start();
    }

    /// Sets a custom handler for 404 Not Found responses.
    pub fn setNotFoundHandler(self: *App, handler: HandlerFn) void {
        self.router.not_found_handler = handler;
    }

    /// Sets a custom error handler for unhandled exceptions.
    pub fn setErrorHandler(self: *App, handler: *const fn (*Context, anyerror) Response) void {
        self.router.error_handler = handler;
    }
};

test "app initialization" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator, .{});
    defer app.deinit();
    try std.testing.expectEqualStrings("Zig API Framework", app.config.title);
}

test "app configuration" {
    const allocator = std.testing.allocator;
    var app = try App.init(allocator, .{
        .title = "Test API",
        .version = "1.0.0",
        .debug = true,
    });
    defer app.deinit();
    try std.testing.expectEqualStrings("Test API", app.config.title);
    try std.testing.expect(app.config.debug);
}
