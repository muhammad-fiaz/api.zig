//! HTTP Server
//!
//! Multi-threaded server with routing and documentation endpoints.

const std = @import("std");
const builtin = @import("builtin");
const http = @import("http.zig");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Context = @import("context.zig").Context;
const Router = @import("router.zig");
const Logger = @import("logger.zig").Logger;

const ws2_32 = if (builtin.os.tag == .windows) std.os.windows.ws2_32 else struct {};

/// Server configuration options.
pub const ServerConfig = struct {
    address: []const u8 = "127.0.0.1",
    port: u16 = 8000,
    max_body_size: usize = 10 * 1024 * 1024,
    num_threads: ?u8 = null,
    enable_access_log: bool = true,
    auto_port: bool = true,
    max_port_attempts: u16 = 100,
};

/// HTTP server handling connections and routing requests.
pub const Server = struct {
    allocator: std.mem.Allocator,
    config: ServerConfig,
    router: *Router.Router,
    logger: *Logger,
    openapi_json: ?[]const u8 = null,
    stream_server: ?std.net.Server = null,
    actual_port: u16 = 0,
    pool: ?std.Thread.Pool = null,

    const swagger_css = @embedFile("assets/swagger-ui.css");
    const swagger_js = @embedFile("assets/swagger-ui-bundle.js");
    const swagger_preset = @embedFile("assets/swagger-ui-standalone-preset.js");
    const redoc_js = @embedFile("assets/redoc.standalone.js");

    /// Initializes a new server instance with the provided configuration.
    pub fn init(allocator: std.mem.Allocator, router: *Router.Router, config: ServerConfig) !Server {
        return .{
            .allocator = allocator,
            .config = config,
            .router = router,
            .logger = try Logger.init(allocator),
            .stream_server = null,
            .actual_port = config.port,
            .pool = null,
        };
    }

    /// Releases server resources and closes connections.
    pub fn deinit(self: *Server) void {
        if (self.stream_server) |*s| {
            s.deinit();
        }
        if (self.pool) |*p| {
            p.deinit();
        }
        self.logger.deinit();
    }

    /// Sets the OpenAPI JSON specification for documentation endpoints.
    pub fn setOpenApiJson(self: *Server, json_spec: []const u8) void {
        self.openapi_json = json_spec;
    }

    /// Attempts to bind to a port with automatic fallback if enabled.
    fn tryBind(self: *Server) !void {
        var port = self.config.port;
        var attempts: u16 = 0;
        const max_attempts = if (self.config.auto_port) self.config.max_port_attempts else 1;

        while (attempts < max_attempts) : (attempts += 1) {
            const addr = std.net.Address.parseIp(self.config.address, port) catch |e| {
                self.logger.errf("Invalid address: {}", .{e}, null) catch {};
                return e;
            };

            self.stream_server = addr.listen(.{
                .reuse_address = true,
            }) catch |e| {
                if (self.config.auto_port and (e == error.AddressInUse or e == error.AlreadyBound)) {
                    port += 1;
                    continue;
                }
                return e;
            };

            self.actual_port = port;
            return;
        }

        return error.AddressInUse;
    }

    /// Starts the server and begins accepting connections.
    pub fn start(self: *Server) !void {
        try self.tryBind();

        // Initialize thread pool if needed
        var num_threads: usize = 1;
        if (self.config.num_threads) |n| {
            num_threads = n;
        } else {
            num_threads = try std.Thread.getCpuCount();
        }

        if (num_threads > 1) {
            self.pool = std.Thread.Pool{ .allocator = self.allocator };
            try self.pool.?.init(.{ .allocator = self.allocator, .n_jobs = @intCast(num_threads) });
        }

        const url = try std.fmt.allocPrint(self.allocator, "http://{s}:{d}", .{ self.config.address, self.actual_port });
        defer self.allocator.free(url);

        try self.logger.success(url);

        if (self.config.enable_access_log) {
            try self.logger.info("  /docs   - Swagger UI (Interactive)", null);
            try self.logger.info("  /redoc  - ReDoc (Reference)", null);
        }

        if (self.pool) |_| {
            try self.logger.infof("Running with {d} worker threads", .{num_threads}, null);
        } else {
            try self.logger.info("Running in single-threaded mode", null);
        }

        while (true) {
            if (self.stream_server) |*stream_server| {
                const conn = stream_server.accept() catch |e| {
                    self.logger.errf("Accept error: {}", .{e}, null) catch {};
                    continue;
                };

                if (self.pool) |*pool| {
                    pool.spawn(handleClientAsync, .{ self, conn.stream }) catch |e| {
                        self.logger.errf("Spawn error: {}", .{e}, null) catch {};
                        conn.stream.close();
                    };
                } else {
                    self.handleClient(conn.stream) catch |e| {
                        self.logger.errf("Client error: {}", .{e}, null) catch {};
                    };
                }
            }
        }
    }

    fn handleClientAsync(self: *Server, stream: std.net.Stream) void {
        self.handleClient(stream) catch |e| {
            self.logger.errf("Client error: {}", .{e}, null) catch {};
        };
    }

    fn socketRecv(handle: std.net.Stream.Handle, buf: []u8) !usize {
        if (builtin.os.tag == .windows) {
            const socket: ws2_32.SOCKET = @ptrCast(handle);
            const result = ws2_32.recv(socket, buf.ptr, @intCast(buf.len), 0);
            if (result == ws2_32.SOCKET_ERROR) {
                return error.SocketError;
            }
            return @intCast(result);
        } else {
            return std.posix.read(handle, buf) catch |e| {
                return e;
            };
        }
    }

    fn socketSend(handle: std.net.Stream.Handle, data: []const u8) !void {
        if (builtin.os.tag == .windows) {
            const socket: ws2_32.SOCKET = @ptrCast(handle);
            var sent: usize = 0;
            while (sent < data.len) {
                const result = ws2_32.send(socket, data[sent..].ptr, @intCast(data.len - sent), 0);
                if (result == ws2_32.SOCKET_ERROR) {
                    return error.SocketError;
                }
                sent += @intCast(result);
            }
        } else {
            _ = try std.posix.write(handle, data);
        }
    }

    fn handleClient(self: *Server, stream: std.net.Stream) !void {
        defer stream.close();

        var buf: [8192]u8 = undefined;

        const n = socketRecv(stream.handle, &buf) catch |e| {
            self.logger.errf("Read error: {}", .{e}, null) catch {};
            return;
        };

        if (n == 0) return;

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var request = Request.parse(arena.allocator(), buf[0..n]) catch {
            const bad_request = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nContent-Length: 11\r\nConnection: close\r\n\r\nBad Request";
            socketSend(stream.handle, bad_request) catch {};
            return;
        };

        if (self.config.enable_access_log) {
            self.logger.infof("{s} {s}", .{ request.method.toString(), request.path }, null) catch {};
        }

        var ctx = Context.init(arena.allocator(), &request, self.logger);
        const response = self.route(&ctx);

        const output = response.format(self.allocator) catch {
            const err_response = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nContent-Length: 21\r\nConnection: close\r\n\r\nInternal Server Error";
            socketSend(stream.handle, err_response) catch {};
            return;
        };
        defer self.allocator.free(output);

        socketSend(stream.handle, output) catch |e| {
            self.logger.errf("Write error: {}", .{e}, null) catch {};
        };
    }

    fn route(self: *Server, ctx: *Context) Response {
        const path = ctx.path();

        // Documentation routes
        if (std.mem.eql(u8, path, "/docs")) return Response.html(swagger_html);
        if (std.mem.eql(u8, path, "/redoc")) return Response.html(redoc_html);
        if (std.mem.eql(u8, path, "/openapi.json")) {
            if (self.openapi_json) |j| return Response.jsonRaw(j);
            return Response.jsonRaw(default_openapi);
        }

        // Assets
        if (std.mem.eql(u8, path, "/docs/swagger-ui.css"))
            return Response.ok(swagger_css).setContentType("text/css");
        if (std.mem.eql(u8, path, "/docs/swagger-ui-bundle.js"))
            return Response.ok(swagger_js).setContentType("application/javascript");
        if (std.mem.eql(u8, path, "/docs/swagger-ui-standalone-preset.js"))
            return Response.ok(swagger_preset).setContentType("application/javascript");
        if (std.mem.eql(u8, path, "/docs/redoc.standalone.js"))
            return Response.ok(redoc_js).setContentType("application/javascript");

        // User routes
        if (self.router.match(ctx.method(), path)) |match| {
            for (match.params.items[0..match.params.len]) |p| {
                ctx.params.put(p.name, p.value) catch continue;
            }
            return match.route.handler(ctx);
        }

        return Response.err(.not_found, "{\"error\":\"Not Found\"}");
    }

    const swagger_html =
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="UTF-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\<title>Zig API Framework - Swagger UI</title>
        \\<link rel="stylesheet" href="/docs/swagger-ui.css">
        \\<style>
        \\:root{--bg:#fafafa;--card-bg:#fff;--text:#3b4151;--text-secondary:#606060;--border:#e0e0e0;--header-bg:linear-gradient(135deg,#f7a41d 0%,#ff8c00 100%)}
        \\.dark{--bg:#0d1117;--card-bg:#161b22;--text:#e6edf3;--text-secondary:#8b949e;--border:#30363d;--header-bg:linear-gradient(135deg,#1a1a2e 0%,#0d1117 100%)}
        \\*{box-sizing:border-box;margin:0;padding:0}
        \\html,body{height:100%;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;transition:background .2s,color .2s}
        \\.swagger-ui,.swagger-ui .info .title,.swagger-ui .info .base-url,.swagger-ui .info p,.swagger-ui .info li,
        \\.swagger-ui .opblock .opblock-summary-description,.swagger-ui .opblock-description-wrapper p,
        \\.swagger-ui .opblock-external-docs-wrapper,.swagger-ui .opblock-title_normal p,.swagger-ui table thead tr td,
        \\.swagger-ui table thead tr th,.swagger-ui .parameter__name,.swagger-ui .parameter__type,
        \\.swagger-ui .response-col_status,.swagger-ui .response-col_description,.swagger-ui .response-col_links,
        \\.swagger-ui .tab li,.swagger-ui .opblock-tag,.swagger-ui label,.swagger-ui .btn,.swagger-ui select,
        \\.swagger-ui .model-title,.swagger-ui .model,.swagger-ui span,.swagger-ui .prop-type,.swagger-ui .prop-format{color:var(--text)!important}
        \\.swagger-ui .opblock .opblock-section-header{background:var(--card-bg);border-color:var(--border)}
        \\.swagger-ui .opblock .opblock-section-header h4{color:var(--text)}
        \\.swagger-ui .opblock{background:var(--card-bg);border-color:var(--border)}
        \\.swagger-ui .opblock-body pre.microlight{background:var(--bg)!important;color:var(--text)!important;border:1px solid var(--border)}
        \\.swagger-ui input[type=text],.swagger-ui input[type=password],.swagger-ui input[type=search],
        \\.swagger-ui input[type=email],.swagger-ui input[type=file],.swagger-ui textarea,.swagger-ui select{background:var(--bg);color:var(--text);border:1px solid var(--border)}
        \\.swagger-ui .model-box{background:var(--card-bg)}
        \\.swagger-ui section.models{border:1px solid var(--border);background:var(--card-bg)}
        \\.swagger-ui section.models.is-open h4{border-color:var(--border)}
        \\.swagger-ui .scheme-container{background:var(--bg);box-shadow:none;padding:15px 0}
        \\.swagger-ui .info .title{color:#f7a41d!important}
        \\.swagger-ui .info .title small.version-stamp{background:#f7a41d}
        \\.swagger-ui .btn.authorize{border-color:#f7a41d;color:#f7a41d}
        \\.swagger-ui .btn.authorize svg{fill:#f7a41d}
        \\.swagger-ui .opblock.opblock-get .opblock-summary-method{background:#61affe}
        \\.swagger-ui .opblock.opblock-post .opblock-summary-method{background:#49cc90}
        \\.swagger-ui .opblock.opblock-put .opblock-summary-method{background:#fca130}
        \\.swagger-ui .opblock.opblock-delete .opblock-summary-method{background:#f93e3e}
        \\.swagger-ui .opblock.opblock-patch .opblock-summary-method{background:#50e3c2}
        \\.swagger-ui .wrapper{max-width:1460px;padding:0 20px}
        \\.swagger-ui .opblock-tag{border-color:var(--border)}
        \\.swagger-ui .opblock-tag:hover{background:var(--card-bg)}
        \\.swagger-ui .loading-container .loading::after{color:var(--text)}
        \\.api-header{background:var(--header-bg);padding:10px 16px;color:#fff;display:flex;align-items:center;gap:10px;position:sticky;top:0;z-index:1000;flex-wrap:wrap}
        \\.api-header h1{font-size:16px;font-weight:600;display:flex;align-items:center;gap:6px}
        \\.api-header .tagline{opacity:.9;font-size:11px}
        \\.api-header nav{margin-left:auto;display:flex;gap:8px;align-items:center}
        \\.api-header nav a{color:#fff;text-decoration:none;font-size:12px;font-weight:500;opacity:.85;padding:5px 10px;border-radius:4px;transition:all .2s}
        \\.api-header nav a:hover,.api-header nav a.active{opacity:1;background:rgba(255,255,255,.15)}
        \\.theme-toggle{background:rgba(255,255,255,.15);border:none;color:#fff;width:32px;height:32px;border-radius:4px;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center;transition:background .2s}
        \\.theme-toggle:hover{background:rgba(255,255,255,.25)}
        \\@media(max-width:600px){.api-header .tagline{display:none}.api-header h1{font-size:14px}.api-header nav a{font-size:11px;padding:4px 8px}}
        \\</style>
        \\</head>
        \\<body>
        \\<div class="api-header">
        \\<h1>Zig API Framework</h1>
        \\<span class="tagline">High Performance, Pure Zig</span>
        \\<nav>
        \\<a href="/docs" class="active">Swagger</a>
        \\<a href="/redoc">ReDoc</a>
        \\<a href="/openapi.json" target="_blank">OpenAPI</a>
        \\<button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme" id="theme-btn">Dark</button>
        \\</nav>
        \\</div>
        \\<div id="swagger-ui"></div>
        \\<script src="/docs/swagger-ui-bundle.js"></script>
        \\<script src="/docs/swagger-ui-standalone-preset.js"></script>
        \\<script>
        \\function setTheme(dark){document.documentElement.classList.toggle('dark',dark);document.getElementById('theme-btn').textContent=dark?'Light':'Dark';localStorage.setItem('theme',dark?'dark':'light')}
        \\function toggleTheme(){setTheme(!document.documentElement.classList.contains('dark'))}
        \\setTheme(localStorage.getItem('theme')==='dark'||(!localStorage.getItem('theme')&&matchMedia('(prefers-color-scheme:dark)').matches));
        \\SwaggerUIBundle({url:"/openapi.json",dom_id:"#swagger-ui",deepLinking:true,presets:[SwaggerUIBundle.presets.apis],plugins:[SwaggerUIBundle.plugins.DownloadUrl],layout:"BaseLayout",defaultModelsExpandDepth:1,docExpansion:"list",filter:true,tryItOutEnabled:true});
        \\</script>
        \\</body>
        \\</html>
    ;

    const redoc_html =
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="UTF-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\<title>Zig API Framework - ReDoc</title>
        \\<style>
        \\:root{--bg:#fafafa;--header-bg:linear-gradient(135deg,#f7a41d 0%,#ff8c00 100%)}
        \\.dark{--bg:#0d1117;--header-bg:linear-gradient(135deg,#1a1a2e 0%,#0d1117 100%)}
        \\*{box-sizing:border-box;margin:0;padding:0}
        \\html,body{height:100%;background:var(--bg);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;transition:background .2s}
        \\.api-header{background:var(--header-bg);padding:10px 16px;color:#fff;display:flex;align-items:center;gap:10px;position:sticky;top:0;z-index:1000;flex-wrap:wrap}
        \\.api-header h1{font-size:16px;font-weight:600;display:flex;align-items:center;gap:6px}
        \\.api-header .tagline{opacity:.9;font-size:11px}
        \\.api-header nav{margin-left:auto;display:flex;gap:8px;align-items:center}
        \\.api-header nav a{color:#fff;text-decoration:none;font-size:12px;font-weight:500;opacity:.85;padding:5px 10px;border-radius:4px;transition:all .2s}
        \\.api-header nav a:hover,.api-header nav a.active{opacity:1;background:rgba(255,255,255,.15)}
        \\.theme-toggle{background:rgba(255,255,255,.15);border:none;color:#fff;width:32px;height:32px;border-radius:4px;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center;transition:background .2s}
        \\.theme-toggle:hover{background:rgba(255,255,255,.25)}
        \\@media(max-width:600px){.api-header .tagline{display:none}.api-header h1{font-size:14px}.api-header nav a{font-size:11px;padding:4px 8px}}
        \\#redoc-container{height:calc(100vh - 52px)}
        \\</style>
        \\</head>
        \\<body>
        \\<div class="api-header">
        \\<h1>Zig API Framework</h1>
        \\<span class="tagline">High Performance, Pure Zig</span>
        \\<nav>
        \\<a href="/docs">Swagger</a>
        \\<a href="/redoc" class="active">ReDoc</a>
        \\<a href="/openapi.json" target="_blank">OpenAPI</a>
        \\<button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme" id="theme-btn">Dark</button>
        \\</nav>
        \\</div>
        \\<div id="redoc-container"></div>
        \\<script src="/docs/redoc.standalone.js"></script>
        \\<script>
        \\var defined=typeof Redoc!=='undefined';
        \\function darkTheme(){return{colors:{primary:{main:'#f7a41d'},text:{primary:'#e6edf3',secondary:'#8b949e'},responses:{success:{backgroundColor:'#1a3d2e'},error:{backgroundColor:'#4a1c1c'}},http:{get:'#61affe',post:'#49cc90',put:'#fca130',delete:'#f93e3e',patch:'#50e3c2'}},schema:{nestedBackground:'#161b22',typeNameColor:'#f7a41d'},sidebar:{backgroundColor:'#0d1117',textColor:'#e6edf3'},rightPanel:{backgroundColor:'#161b22',textColor:'#e6edf3'},typography:{fontSize:'14px',fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif',headings:{fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif'},code:{backgroundColor:'#0d1117'}}}}
        \\function lightTheme(){return{colors:{primary:{main:'#f7a41d'}},typography:{fontSize:'14px',fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif',headings:{fontFamily:'-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif'}}}}
        \\function initRedoc(dark){if(!defined)return;document.getElementById('redoc-container').innerHTML='';Redoc.init('/openapi.json',{hideHostname:true,hideDownloadButton:false,nativeScrollbars:true,theme:dark?darkTheme():lightTheme()},document.getElementById('redoc-container'))}
        \\function setTheme(dark){document.documentElement.classList.toggle('dark',dark);document.getElementById('theme-btn').textContent=dark?'Light':'Dark';localStorage.setItem('theme',dark?'dark':'light');initRedoc(dark)}
        \\function toggleTheme(){setTheme(!document.documentElement.classList.contains('dark'))}
        \\var isDark=localStorage.getItem('theme')==='dark'||(!localStorage.getItem('theme')&&matchMedia('(prefers-color-scheme:dark)').matches);
        \\document.documentElement.classList.toggle('dark',isDark);document.getElementById('theme-btn').textContent=isDark?'Light':'Dark';initRedoc(isDark);
        \\</script>
        \\</body>
        \\</html>
    ;

    const default_openapi =
        \\{"openapi":"3.1.0","info":{"title":"API","version":"1.0.0"},"paths":{}}
    ;
};

test "server init" {
    var router = Router.Router.init(std.testing.allocator);
    defer router.deinit();
    var server = try Server.init(std.testing.allocator, &router, .{});
    defer server.deinit();
}
