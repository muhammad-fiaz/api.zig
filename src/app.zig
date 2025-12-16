//! Application orchestrator for HTTP routing, middleware, and server lifecycle.
//! Provides a high-level API for building web applications with automatic OpenAPI generation.
//! Supports GraphQL, WebSockets, caching, sessions, and metrics for production deployments.

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
const graphql = @import("graphql.zig");
const websocket = @import("websocket.zig");
const metrics = @import("metrics.zig");
const cache = @import("cache.zig");
const session = @import("session.zig");

/// Application configuration.
pub const AppConfig = struct {
    title: []const u8 = "Zig API Framework",
    version: []const u8 = "1.0.0",
    description: ?[]const u8 = "High-performance API framework for Zig with automatic OpenAPI generation",
    debug: bool = false,
    docs_url: []const u8 = "/docs",
    redoc_url: []const u8 = "/redoc",
    openapi_url: []const u8 = "/openapi.json",
    /// GraphQL endpoint configuration
    graphql_url: ?[]const u8 = null,
    graphql_playground_url: ?[]const u8 = null,
    /// WebSocket endpoint
    websocket_url: ?[]const u8 = null,
    /// Metrics endpoint
    metrics_url: ?[]const u8 = null,
    /// Health check endpoint
    health_url: ?[]const u8 = "/health",
    /// Enable session management
    enable_sessions: bool = false,
    /// Enable response caching
    enable_caching: bool = false,
};

/// Comptime GraphQL configuration for static path registration.
pub const GraphQLComptimeConfig = struct {
    /// Path for GraphQL Playground UI
    playground_path: ?[]const u8 = null,
    /// Path for GraphiQL IDE
    graphiql_path: ?[]const u8 = null,
    /// Path for Apollo Sandbox
    apollo_sandbox_path: ?[]const u8 = null,
    /// Path for Altair GraphQL Client
    altair_path: ?[]const u8 = null,
    /// Path for GraphQL Voyager
    voyager_path: ?[]const u8 = null,
    /// Enable playground
    enable_playground: bool = true,
    /// Enable introspection
    enable_introspection: bool = true,
};

/// Server runtime configuration.
pub const RunConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8000,
    access_log: bool = true,
    num_threads: ?u8 = null,
    auto_port: bool = true,
    disable_reserved_routes: bool = false,
};

/// Main application type.
pub const App = struct {
    allocator: std.mem.Allocator,
    config: AppConfig,
    router: Router.Router,
    openapi: OpenAPI,
    logger: *Logger,
    middleware: std.ArrayListUnmanaged(MiddlewareFn) = .{},

    // Optional production features
    graphql_schema: ?*graphql.Schema = null,
    ws_hub: ?*websocket.Hub = null,
    metrics_registry: ?*metrics.Registry = null,
    response_cache: ?*cache.ResponseCache = null,
    session_manager: ?*session.Manager = null,
    health_checker: ?*metrics.HealthChecker = null,

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

    /// Registers an OPTIONS route handler for the specified path pattern.
    pub fn options(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.OPTIONS, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("OPTIONS", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a HEAD route handler for the specified path pattern.
    pub fn head(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.HEAD, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("HEAD", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Registers a TRACE route handler for the specified path pattern.
    pub fn trace(self: *App, comptime path: []const u8, handler: anytype) !void {
        const compiled_route = comptime Router.Router.register(.TRACE, path, handler);
        try self.router.addRoute(compiled_route);
        try self.openapi.addPath("TRACE", path, compiled_route.summary, compiled_route.description, compiled_route.tags, compiled_route.deprecated);
    }

    /// Mounts a sub-router at a path prefix with optional tag overrides.
    pub fn include_router(self: *App, router: *const Router.Router, prefix: []const u8, tags: []const []const u8) !void {
        try self.router.include_router(router, prefix, tags);
        for (router.routes.items) |r| {
            const prefixed_path = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ prefix, r.path });
            const merged_tags = if (tags.len > 0) tags else r.tags;
            try self.openapi.addPath(r.method.toString(), prefixed_path, r.summary, r.description, merged_tags, r.deprecated);
        }
    }

    /// Adds a middleware to the application pipeline.
    pub fn add_middleware(self: *App, middleware: MiddlewareFn) !void {
        try self.middleware.append(self.allocator, middleware);
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

    /// Serves static files from a directory at the specified URL prefix.
    pub fn serveStatic(self: *App, comptime url_prefix: []const u8, comptime directory: []const u8) !void {
        const static_mod = @import("static.zig");
        const handler = static_mod.StaticFiles.serve(.{
            .root_path = directory,
            .url_prefix = url_prefix,
            .html5_mode = false,
        });
        const route_path = if (std.mem.eql(u8, url_prefix, "/")) "/{path...}" else url_prefix ++ "/{path...}";
        try self.get(route_path, handler);
        try self.logger.info("Static files: {s} -> {s}", .{ url_prefix, directory });
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
            .disable_reserved_routes = config.disable_reserved_routes,
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

    /// Configures GraphQL support with the provided schema using comptime paths.
    /// Use this for static GraphQL configuration at compile time.
    pub fn enableGraphQLComptime(
        self: *App,
        schema: *graphql.Schema,
        comptime path: []const u8,
        comptime config: GraphQLComptimeConfig,
    ) !void {
        self.graphql_schema = schema;

        // Register GraphQL endpoint
        const GraphQLHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.json(.{ .message = "GraphQL endpoint active" });
            }
        };
        try self.post(path, GraphQLHandler.handle);
        try self.get(path, GraphQLHandler.handle);

        // Register Playground if path is set
        if (config.playground_path) |playground_path| {
            const PlaygroundHandler = struct {
                fn handle(ctx: *Context) Response {
                    _ = ctx;
                    return Response.html(graphql.graphqlPlayground(path));
                }
            };
            try self.get(playground_path, PlaygroundHandler.handle);
            try self.logger.info("GraphQL Playground enabled at {s}", .{playground_path});
        }

        // Register GraphiQL if path is set
        if (config.graphiql_path) |graphiql_path| {
            const GraphiQLHandler = struct {
                fn handle(ctx: *Context) Response {
                    _ = ctx;
                    return Response.html(graphql.graphiql(path));
                }
            };
            try self.get(graphiql_path, GraphiQLHandler.handle);
            try self.logger.info("GraphiQL enabled at {s}", .{graphiql_path});
        }

        // Register Apollo Sandbox if path is set
        if (config.apollo_sandbox_path) |sandbox_path| {
            const SandboxHandler = struct {
                fn handle(ctx: *Context) Response {
                    _ = ctx;
                    return Response.html(graphql.apolloSandbox(path));
                }
            };
            try self.get(sandbox_path, SandboxHandler.handle);
            try self.logger.info("Apollo Sandbox enabled at {s}", .{sandbox_path});
        }

        // Register Altair if path is set
        if (config.altair_path) |altair_path| {
            const AltairHandler = struct {
                fn handle(ctx: *Context) Response {
                    _ = ctx;
                    return Response.html(graphql.altairGraphQL(path));
                }
            };
            try self.get(altair_path, AltairHandler.handle);
            try self.logger.info("Altair GraphQL Client enabled at {s}", .{altair_path});
        }

        // Register Voyager if path is set
        if (config.voyager_path) |voyager_path| {
            const VoyagerHandler = struct {
                fn handle(ctx: *Context) Response {
                    _ = ctx;
                    return Response.html(graphql.graphqlVoyager(path));
                }
            };
            try self.get(voyager_path, VoyagerHandler.handle);
            try self.logger.info("GraphQL Voyager enabled at {s}", .{voyager_path});
        }

        try self.logger.info("GraphQL enabled at {s}", .{path});
    }

    /// Configures GraphQL support with the provided schema (runtime version).
    /// For most use cases, prefer enableGraphQLComptime with comptime paths.
    pub fn enableGraphQL(self: *App, schema: *graphql.Schema, config: graphql.GraphQLConfig) !void {
        // Store schema
        self.graphql_schema = schema;

        // Create introspection response once and cache it
        const introspection_json = schema.toIntrospectionJson(self.allocator) catch "{\"errors\":[{\"message\":\"Failed to generate introspection\"}]}";

        // GraphQL endpoint handler with introspection support
        const GraphQLHandler = struct {
            var cached_introspection: []const u8 = "";

            fn setCachedIntrospection(data: []const u8) void {
                cached_introspection = data;
            }

            fn handle(ctx: *Context) Response {
                // Handle CORS preflight
                if (ctx.method() == .OPTIONS) {
                    return Response.init()
                        .setStatus(.no_content)
                        .setHeader("Access-Control-Allow-Origin", "*")
                        .setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
                        .setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept, Origin, X-Requested-With, apollo-require-preflight")
                        .setHeader("Access-Control-Max-Age", "86400");
                }

                // For POST requests, check if it's an introspection query
                const body = ctx.body();
                if (body.len > 0 and std.mem.indexOf(u8, body, "__schema") != null) {
                    return Response.jsonRaw(cached_introspection)
                        .setHeader("Access-Control-Allow-Origin", "*");
                }

                // For GET requests with introspection
                if (ctx.method() == .GET) {
                    if (ctx.query("query")) |query| {
                        if (std.mem.indexOf(u8, query, "__schema") != null) {
                            return Response.jsonRaw(cached_introspection)
                                .setHeader("Access-Control-Allow-Origin", "*");
                        }
                    }
                }

                // Default response for non-introspection queries
                return Response.json(.{ .data = null, .message = "Query execution not yet implemented" })
                    .setHeader("Access-Control-Allow-Origin", "*");
            }
        };

        // Set the cached introspection data
        GraphQLHandler.setCachedIntrospection(introspection_json);

        const PlaygroundHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.html(graphql.graphqlPlayground("/graphql"));
            }
        };

        const GraphiQLHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.html(graphql.graphiql("/graphql"));
            }
        };

        const SandboxHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.html(graphql.apolloSandbox("/graphql"));
            }
        };

        const AltairHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.html(graphql.altairGraphQL("/graphql"));
            }
        };

        const VoyagerHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.html(graphql.graphqlVoyager("/graphql"));
            }
        };

        // Register routes using runtime route registration
        // GraphQL main endpoint - POST for queries/mutations
        try self.router.addRoute(.{
            .method = .POST,
            .path = config.path,
            .handler = GraphQLHandler.handle,
            .summary = "GraphQL endpoint",
            .description = "Execute GraphQL queries and mutations",
            .tags = &.{"GraphQL"},
        });
        // GraphQL endpoint - GET for queries
        try self.router.addRoute(.{
            .method = .GET,
            .path = config.path,
            .handler = GraphQLHandler.handle,
            .summary = "GraphQL endpoint",
            .description = "Execute GraphQL queries via GET",
            .tags = &.{"GraphQL"},
        });
        // GraphQL endpoint - OPTIONS for CORS preflight
        try self.router.addRoute(.{
            .method = .OPTIONS,
            .path = config.path,
            .handler = GraphQLHandler.handle,
            .summary = "GraphQL CORS preflight",
            .description = "Handle CORS preflight requests",
            .tags = &.{"GraphQL"},
        });

        // Register UI endpoints
        if (config.enable_playground) {
            if (config.playground_path) |playground| {
                try self.router.addRoute(.{
                    .method = .GET,
                    .path = playground,
                    .handler = PlaygroundHandler.handle,
                    .summary = "GraphQL Playground",
                    .tags = &.{"GraphQL"},
                });
                try self.logger.info("GraphQL Playground enabled at {s}", .{playground});
            }
        }

        if (config.graphiql_path) |graphiql_path| {
            try self.router.addRoute(.{
                .method = .GET,
                .path = graphiql_path,
                .handler = GraphiQLHandler.handle,
                .summary = "GraphiQL IDE",
                .tags = &.{"GraphQL"},
            });
            try self.logger.info("GraphiQL enabled at {s}", .{graphiql_path});
        }

        if (config.apollo_sandbox_path) |sandbox_path| {
            try self.router.addRoute(.{
                .method = .GET,
                .path = sandbox_path,
                .handler = SandboxHandler.handle,
                .summary = "Apollo Sandbox",
                .tags = &.{"GraphQL"},
            });
            try self.logger.info("Apollo Sandbox enabled at {s}", .{sandbox_path});
        }

        if (config.altair_path) |altair_path| {
            try self.router.addRoute(.{
                .method = .GET,
                .path = altair_path,
                .handler = AltairHandler.handle,
                .summary = "Altair GraphQL Client",
                .tags = &.{"GraphQL"},
            });
            try self.logger.info("Altair GraphQL Client enabled at {s}", .{altair_path});
        }

        if (config.voyager_path) |voyager_path| {
            try self.router.addRoute(.{
                .method = .GET,
                .path = voyager_path,
                .handler = VoyagerHandler.handle,
                .summary = "GraphQL Voyager",
                .tags = &.{"GraphQL"},
            });
            try self.logger.info("GraphQL Voyager enabled at {s}", .{voyager_path});
        }

        try self.logger.info("GraphQL enabled at {s}", .{config.path});
    }

    /// Enables all GraphQL UIs at their default paths
    pub fn enableAllGraphQLUIs(self: *App, schema: *graphql.Schema) !void {
        try self.enableGraphQL(schema, .{
            .schema = schema,
            .playground_path = "/graphql/playground",
            .graphiql_path = "/graphql/graphiql",
            .apollo_sandbox_path = "/graphql/sandbox",
            .altair_path = "/graphql/altair",
            .voyager_path = "/graphql/voyager",
        });
    }

    /// Returns the GraphQL schema if configured.
    pub fn getGraphQLSchema(self: *App) ?*graphql.Schema {
        return self.graphql_schema;
    }

    /// Configures WebSocket support.
    pub fn enableWebSocket(self: *App, config: websocket.WebSocketConfig) !void {
        self.ws_hub = try self.allocator.create(websocket.Hub);
        self.ws_hub.?.* = websocket.Hub.init(self.allocator, .{
            .max_connections = 10000,
            .max_message_size = config.max_message_size,
            .ping_interval_ms = config.ping_interval_ms,
            .pong_timeout_ms = config.pong_timeout_ms,
        });

        self.logger.info("WebSocket enabled at {s}", .{config.path});
    }

    /// Returns the WebSocket hub for connection management.
    pub fn getWebSocketHub(self: *App) ?*websocket.Hub {
        return self.ws_hub;
    }

    /// Configures metrics collection and export.
    pub fn enableMetrics(self: *App, config: metrics.RegistryConfig) !void {
        self.metrics_registry = try self.allocator.create(metrics.Registry);
        self.metrics_registry.?.* = try metrics.Registry.init(self.allocator, config);

        // Register metrics endpoint
        if (self.config.metrics_url) |metrics_path| {
            const MetricsHandler = struct {
                fn handle(ctx: *Context) Response {
                    _ = ctx;
                    return Response.text("# Prometheus metrics\n");
                }
            };
            try self.get(metrics_path, MetricsHandler.handle);
            self.logger.info("Metrics enabled at {s}", .{metrics_path});
        }
    }

    /// Returns the metrics registry.
    pub fn getMetricsRegistry(self: *App) ?*metrics.Registry {
        return self.metrics_registry;
    }

    /// Configures health check endpoints.
    pub fn enableHealthChecks(self: *App, config: metrics.HealthChecker.HealthConfig) !void {
        self.health_checker = try self.allocator.create(metrics.HealthChecker);
        self.health_checker.?.* = metrics.HealthChecker.init(self.allocator, config);

        // Register basic ping check
        try self.health_checker.?.register("ping", metrics.Checks.pingCheck);

        // Register health endpoint
        const HealthHandler = struct {
            fn handle(ctx: *Context) Response {
                _ = ctx;
                return Response.json(.{ .status = "healthy" });
            }
        };
        try self.get(config.path, HealthHandler.handle);
        self.logger.info("Health checks enabled at {s}", .{config.path});
    }

    /// Registers a custom health check.
    pub fn addHealthCheck(self: *App, name: []const u8, check: metrics.CheckFn) !void {
        if (self.health_checker) |checker| {
            try checker.register(name, check);
        }
    }

    /// Configures response caching.
    pub fn enableCaching(self: *App, config: cache.ResponseCache.ResponseCacheConfig) !void {
        self.response_cache = try self.allocator.create(cache.ResponseCache);
        self.response_cache.?.* = cache.ResponseCache.init(self.allocator, config);
        self.logger.info("Response caching enabled", .{});
    }

    /// Returns the response cache.
    pub fn getCache(self: *App) ?*cache.ResponseCache {
        return self.response_cache;
    }

    /// Configures session management.
    pub fn enableSessions(self: *App, config: session.SessionConfig) !void {
        const store = try self.allocator.create(session.MemoryStore);
        store.* = session.MemoryStore.init(self.allocator, config);

        self.session_manager = try self.allocator.create(session.Manager);
        self.session_manager.?.* = session.Manager.init(self.allocator, store.store(), config);
        self.logger.info("Session management enabled", .{});
    }

    /// Returns the session manager.
    pub fn getSessionManager(self: *App) ?*session.Manager {
        return self.session_manager;
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
