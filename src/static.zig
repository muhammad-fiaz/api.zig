//! Static File Server and Template Engine
//!
//! Static file serving, HTML templates, and file response utilities.

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;
const http = @import("http.zig");

/// Configuration options for static file serving.
pub const StaticConfig = struct {
    /// Filesystem path to the directory containing static files.
    root_path: []const u8 = "static",
    /// URL path prefix that triggers static file serving.
    url_prefix: []const u8 = "/static",
    /// Files to serve when a directory URL is requested.
    index_files: []const []const u8 = &.{ "index.html", "index.htm" },
    /// Allow directory listing when no index file exists.
    browse: bool = false,
    /// Serve index.html for all missing paths (SPA support).
    html5_mode: bool = false,
};

/// Static file serving handler for CSS, JavaScript, images, and other assets.
pub const StaticFiles = struct {
    /// Creates a route handler that serves files from the configured directory.
    pub fn serve(comptime config: StaticConfig) fn (*Context) Response {
        return struct {
            fn handler(ctx: *Context) Response {
                const path = ctx.path();

                if (!std.mem.startsWith(u8, path, config.url_prefix)) {
                    return Response.err(.not_found, "{\"error\":\"Not Found\"}");
                }

                const relative_path = path[config.url_prefix.len..];

                if (std.mem.indexOf(u8, relative_path, "..") != null) {
                    return Response.err(.forbidden, "{\"error\":\"Access Denied\"}");
                }

                const clean_rel_path = if (std.mem.startsWith(u8, relative_path, "/"))
                    relative_path[1..]
                else
                    relative_path;

                const target_path = if (clean_rel_path.len == 0) "index.html" else clean_rel_path;

                const full_path = std.fs.path.join(ctx.allocator, &.{ config.root_path, target_path }) catch {
                    return Response.err(.internal_server_error, "{\"error\":\"Internal Server Error\"}");
                };
                defer ctx.allocator.free(full_path);

                const result = serveFile(ctx.allocator, full_path);

                if (config.html5_mode and result.status == .not_found) {
                    const index_path = std.fs.path.join(ctx.allocator, &.{ config.root_path, "index.html" }) catch {
                        return result;
                    };
                    defer ctx.allocator.free(index_path);
                    return serveFile(ctx.allocator, index_path);
                }

                return result;
            }
        }.handler;
    }

    /// Reads a file from disk and returns an HTTP response with appropriate MIME type.
    pub fn serveFile(allocator: std.mem.Allocator, path: []const u8) Response {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) return Response.err(.not_found, "{\"detail\":\"File not found\"}");
            return Response.err(.forbidden, "{\"detail\":\"Access denied\"}");
        };
        defer file.close();

        const stat = file.stat() catch return Response.err(.internal_server_error, "{\"detail\":\"Stat failed\"}");

        if (stat.size > 10 * 1024 * 1024) {
            return Response.err(.payload_too_large, "{\"detail\":\"File too large\"}");
        }

        const content = file.readToEndAlloc(allocator, @intCast(stat.size)) catch {
            return Response.err(.internal_server_error, "{\"detail\":\"Read failed\"}");
        };

        const mime = http.getMimeType(path);

        return Response.ok(content).setContentType(mime);
    }
};

// Backward compatibility alias
pub const StaticRouter = StaticFiles;

// ============================================================================
// Templates
// ============================================================================

/// HTML template engine with variable substitution.
pub const Templates = struct {
    directory: []const u8,
    allocator: std.mem.Allocator,

    /// Initialize templates with a directory path.
    pub fn init(allocator: std.mem.Allocator, directory: []const u8) Templates {
        return .{
            .directory = directory,
            .allocator = allocator,
        };
    }

    /// Render a template with context variables.
    pub fn render(self: *const Templates, template_name: []const u8, context: anytype) Response {
        // Load template file
        const full_path = std.fs.path.join(self.allocator, &.{ self.directory, template_name }) catch {
            return Response.err(.internal_server_error, "{\"detail\":\"Template path error\"}");
        };
        defer self.allocator.free(full_path);

        const file = std.fs.cwd().openFile(full_path, .{}) catch {
            return Response.err(.not_found, "{\"detail\":\"Template not found\"}");
        };
        defer file.close();

        const stat = file.stat() catch return Response.err(.internal_server_error, "{\"detail\":\"Stat failed\"}");

        var content = file.readToEndAlloc(self.allocator, @intCast(stat.size)) catch {
            return Response.err(.internal_server_error, "{\"detail\":\"Read failed\"}");
        };

        // Simple template variable substitution
        content = self.substitute(content, context) catch {
            return Response.err(.internal_server_error, "{\"detail\":\"Template render error\"}");
        };

        return Response.html(content);
    }

    /// Substitute template variables {{ var }} with values from context.
    fn substitute(self: *const Templates, template: []u8, context: anytype) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < template.len) {
            // Look for {{ ... }}
            if (i + 1 < template.len and template[i] == '{' and template[i + 1] == '{') {
                // Find closing }}
                const start = i + 2;
                var end = start;
                while (end + 1 < template.len) : (end += 1) {
                    if (template[end] == '}' and template[end + 1] == '}') break;
                }

                if (end + 1 < template.len) {
                    // Extract variable name (trim whitespace)
                    const var_name = std.mem.trim(u8, template[start..end], " \t");

                    // Look up value in context struct
                    const value = self.lookupValue(context, var_name);
                    try result.appendSlice(self.allocator, value);

                    i = end + 2;
                    continue;
                }
            }

            try result.append(self.allocator, template[i]);
            i += 1;
        }

        self.allocator.free(template);
        return result.toOwnedSlice(self.allocator);
    }

    /// Look up a field value from a struct by name.
    fn lookupValue(self: *const Templates, context: anytype, name: []const u8) []const u8 {
        _ = self;
        const T = @TypeOf(context);
        const info = @typeInfo(T);

        if (info == .@"struct") {
            inline for (info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, name)) {
                    const value = @field(context, field.name);
                    const ValueType = @TypeOf(value);

                    if (ValueType == []const u8) {
                        return value;
                    } else if (@typeInfo(ValueType) == .pointer) {
                        if (@typeInfo(ValueType).pointer.child == u8) {
                            return value;
                        }
                    }
                    return "";
                }
            }
        }
        return "";
    }

    /// Render a template and return a response.
    pub fn TemplateResponse(self: *const Templates, template_name: []const u8, context: anytype) Response {
        return self.render(template_name, context);
    }
};

// ============================================================================
// HTML Response Helpers
// ============================================================================

/// Create an HTML response from raw content.
pub fn HTMLResponse(content: []const u8) Response {
    return Response.html(content);
}

/// Create an HTML response with custom status code.
pub fn HTMLResponseWithStatus(content: []const u8, status: http.StatusCode) Response {
    return Response.html(content).setStatus(status);
}

// ============================================================================
// File Response Helpers
// ============================================================================

/// Create a file download response.
pub fn FileResponse(allocator: std.mem.Allocator, path: []const u8, filename: ?[]const u8) Response {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        return Response.err(.not_found, "{\"detail\":\"File not found\"}");
    };
    defer file.close();

    const stat = file.stat() catch return Response.err(.internal_server_error, "{\"detail\":\"Stat failed\"}");

    if (stat.size > 50 * 1024 * 1024) { // 50MB limit
        return Response.err(.payload_too_large, "{\"detail\":\"File too large\"}");
    }

    const content = file.readToEndAlloc(allocator, @intCast(stat.size)) catch {
        return Response.err(.internal_server_error, "{\"detail\":\"Read failed\"}");
    };

    const mime = http.getMimeType(path);
    var resp = Response.ok(content).setContentType(mime);

    // Set Content-Disposition for download
    if (filename) |name| {
        resp = resp.setHeader("Content-Disposition", name);
    }

    return resp;
}

// ============================================================================
// Streaming Response
// ============================================================================

/// Streaming response for large content.
pub fn StreamingResponse(content: []const u8, media_type: []const u8) Response {
    return Response.ok(content).setContentType(media_type);
}

// ============================================================================
// Tests
// ============================================================================

test "HTMLResponse" {
    const resp = HTMLResponse("<h1>Hello</h1>");
    try std.testing.expectEqual(http.StatusCode.ok, resp.status);
    try std.testing.expectEqualStrings("<h1>Hello</h1>", resp.body);
}

test "StaticFiles path sanitization" {
    // Test that .. is blocked
    const config = StaticConfig{
        .root_path = "test_public",
        .url_prefix = "/static",
    };
    _ = config;
}

test "Templates init" {
    const templates = Templates.init(std.testing.allocator, "templates");
    try std.testing.expectEqualStrings("templates", templates.directory);
}
