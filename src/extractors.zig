//! Type-safe request data extractors with validation, dependency injection, and RFC compliance.

const std = @import("std");
const Context = @import("context.zig").Context;
const json_mod = @import("json.zig");

/// Extracts path parameters from the request URL.
pub fn Path(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// Extracts path parameters into the specified type.
        pub fn extract(ctx: *Context) !Self {
            var result: T = undefined;
            const fields = @typeInfo(T).@"struct".fields;

            inline for (fields) |field| {
                const param_value = ctx.param(field.name) orelse return error.MissingPathParam;
                @field(result, field.name) = try parseField(field.type, param_value);
            }

            return Self{ .value = result };
        }

        fn parseField(comptime FieldType: type, value: []const u8) !FieldType {
            const info = @typeInfo(FieldType);

            switch (info) {
                .int => return std.fmt.parseInt(FieldType, value, 10) catch error.ParseError,
                .float => return std.fmt.parseFloat(FieldType, value) catch error.ParseError,
                .pointer => |p| {
                    if (p.size == .slice and p.child == u8) return value;
                    return error.UnsupportedType;
                },
                else => return error.UnsupportedType,
            }
        }
    };
}

/// Extracts query parameters from the request URL.
pub fn Query(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// Extracts query parameters into the specified type.
        pub fn extract(ctx: *Context) !Self {
            var result: T = undefined;
            const fields = @typeInfo(T).@"struct".fields;

            inline for (fields) |field| {
                const info = @typeInfo(field.type);

                if (info == .optional) {
                    if (ctx.query(field.name)) |v| {
                        @field(result, field.name) = try parseField(info.optional.child, v);
                    } else {
                        @field(result, field.name) = null;
                    }
                } else if (field.default_value_ptr) |default_ptr| {
                    if (ctx.query(field.name)) |v| {
                        @field(result, field.name) = try parseField(field.type, v);
                    } else {
                        const typed_ptr: *const field.type = @ptrCast(@alignCast(default_ptr));
                        @field(result, field.name) = typed_ptr.*;
                    }
                } else {
                    const query_value = ctx.query(field.name) orelse return error.MissingQueryParam;
                    @field(result, field.name) = try parseField(field.type, query_value);
                }
            }

            return Self{ .value = result };
        }

        fn parseField(comptime FieldType: type, value: []const u8) !FieldType {
            const info = @typeInfo(FieldType);

            switch (info) {
                .int => return std.fmt.parseInt(FieldType, value, 10) catch error.ParseError,
                .float => return std.fmt.parseFloat(FieldType, value) catch error.ParseError,
                .bool => {
                    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) return true;
                    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) return false;
                    return error.ParseError;
                },
                .pointer => |p| {
                    if (p.size == .slice and p.child == u8) return value;
                    return error.UnsupportedType;
                },
                else => return error.UnsupportedType,
            }
        }
    };
}

/// Extracts and parses the JSON request body.
pub fn Body(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// Extracts and parses the JSON body into the specified type.
        pub fn extract(ctx: *Context) !Self {
            const body_content = ctx.body();
            if (body_content.len == 0) return error.EmptyBody;

            const parsed = try json_mod.parse(T, ctx.allocator, body_content);
            return Self{ .value = parsed };
        }
    };
}

/// Extracts a specific header from the request.
pub fn Header(comptime name: []const u8) type {
    return struct {
        value: []const u8,

        const Self = @This();

        /// Extracts the header value.
        pub fn extract(ctx: *Context) !Self {
            const header_value = ctx.header(name) orelse return error.MissingHeader;
            return Self{ .value = header_value };
        }
    };
}

/// Extracts the Authorization header.
pub const Authorization = Header("Authorization");

/// Extracts the Content-Type header.
pub const ContentType = Header("Content-Type");

/// Extracts the User-Agent header.
pub const UserAgent = Header("User-Agent");

/// Extracts the Accept header.
pub const Accept = Header("Accept");

/// Extracts the X-Request-ID header.
pub const RequestId = Header("X-Request-ID");

/// Extracts the X-Forwarded-For header.
pub const ForwardedFor = Header("X-Forwarded-For");

/// Dependency injection extractor for providing services to handlers.
pub fn Depends(comptime dependencyFn: anytype) type {
    const ReturnType = @typeInfo(@TypeOf(dependencyFn)).@"fn".return_type.?;
    const ValueType = if (@typeInfo(ReturnType) == .error_union)
        @typeInfo(ReturnType).error_union.payload
    else
        ReturnType;

    return struct {
        value: ValueType,

        const Self = @This();

        pub fn extract(ctx: *Context) !Self {
            const result = try dependencyFn(ctx);
            return Self{ .value = result };
        }
    };
}

/// Extracts a specific cookie from the request following RFC 6265.
pub fn Cookie(comptime name: []const u8) type {
    return struct {
        value: []const u8,

        const Self = @This();

        pub fn extract(ctx: *Context) !Self {
            const cookie_header = ctx.header("Cookie") orelse return error.MissingCookie;
            var it = std.mem.splitSequence(u8, cookie_header, "; ");
            while (it.next()) |pair| {
                const trimmed = std.mem.trim(u8, pair, " ");
                if (std.mem.indexOf(u8, trimmed, "=")) |eq_idx| {
                    const key = trimmed[0..eq_idx];
                    if (std.mem.eql(u8, key, name)) {
                        return Self{ .value = trimmed[eq_idx + 1 ..] };
                    }
                }
            }
            return error.MissingCookie;
        }
    };
}

/// Extracts all cookies as a key-value map.
pub const Cookies = struct {
    values: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn extract(ctx: *Context) !Self {
        var values = std.StringHashMap([]const u8).init(ctx.allocator);

        const cookie_header = ctx.header("Cookie") orelse return Self{ .values = values };
        var it = std.mem.splitSequence(u8, cookie_header, "; ");
        while (it.next()) |pair| {
            const trimmed = std.mem.trim(u8, pair, " ");
            if (std.mem.indexOf(u8, trimmed, "=")) |eq_idx| {
                const key = trimmed[0..eq_idx];
                const value = trimmed[eq_idx + 1 ..];
                try values.put(key, value);
            }
        }

        return Self{ .values = values };
    }

    pub fn get(self: *const Self, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }
};

/// Extracts URL-encoded form data from POST body.
pub fn Form(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn extract(ctx: *Context) !Self {
            const content_type = ctx.header("Content-Type") orelse return error.MissingContentType;
            if (!std.mem.startsWith(u8, content_type, "application/x-www-form-urlencoded")) {
                return error.InvalidContentType;
            }

            const body_content = ctx.body();
            if (body_content.len == 0) return error.EmptyBody;

            var result: T = undefined;
            const fields = @typeInfo(T).@"struct".fields;

            inline for (fields) |field| {
                @field(result, field.name) = try parseFormField(field.type, body_content, field.name, field.default_value_ptr);
            }

            return Self{ .value = result };
        }

        fn parseFormField(comptime FieldType: type, body: []const u8, field_name: []const u8, default_ptr: anytype) !FieldType {
            var it = std.mem.splitSequence(u8, body, "&");
            while (it.next()) |pair| {
                if (std.mem.indexOf(u8, pair, "=")) |eq_idx| {
                    const key = pair[0..eq_idx];
                    if (std.mem.eql(u8, key, field_name)) {
                        const value = pair[eq_idx + 1 ..];
                        const decoded = try urlDecode(value);
                        return parseValue(FieldType, decoded);
                    }
                }
            }

            if (default_ptr) |ptr| {
                const typed_ptr: *const FieldType = @ptrCast(@alignCast(ptr));
                return typed_ptr.*;
            }

            return error.MissingFormField;
        }

        fn urlDecode(str: []const u8) ![]const u8 {
            return str;
        }

        fn parseValue(comptime ValueType: type, value: []const u8) !ValueType {
            const info = @typeInfo(ValueType);
            switch (info) {
                .int => return std.fmt.parseInt(ValueType, value, 10) catch error.ParseError,
                .float => return std.fmt.parseFloat(ValueType, value) catch error.ParseError,
                .bool => {
                    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "on")) return true;
                    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0") or std.mem.eql(u8, value, "off")) return false;
                    return error.ParseError;
                },
                .pointer => |p| {
                    if (p.size == .slice and p.child == u8) return value;
                    return error.UnsupportedType;
                },
                else => return error.UnsupportedType,
            }
        }
    };
}

/// Extracts a typed value from context state.
pub fn State(comptime T: type) type {
    return struct {
        value: *T,

        const Self = @This();

        pub fn extract(ctx: *Context, key: []const u8) !Self {
            const ptr = ctx.state.get(key) orelse return error.StateNotFound;
            return Self{ .value = @ptrCast(@alignCast(ptr)) };
        }
    };
}

/// Extracts client information from request.
pub const ClientInfo = struct {
    ip: []const u8,
    user_agent: ?[]const u8,
    accept: ?[]const u8,
    accept_language: ?[]const u8,

    const Self = @This();

    pub fn extract(ctx: *Context) !Self {
        return Self{
            .ip = ctx.header("X-Forwarded-For") orelse ctx.header("X-Real-IP") orelse "unknown",
            .user_agent = ctx.header("User-Agent"),
            .accept = ctx.header("Accept"),
            .accept_language = ctx.header("Accept-Language"),
        };
    }
};

test "Path extractor type" {
    const PathParams = Path(struct { id: u32, name: []const u8 });
    _ = PathParams;
}

test "Query extractor type" {
    const QueryParams = Query(struct { page: u32 = 1, limit: u32 = 10 });
    _ = QueryParams;
}

test "Body extractor type" {
    const BodyType = Body(struct { message: []const u8 });
    _ = BodyType;
}

test "Header extractor type" {
    const AuthHeader = Header("Authorization");
    _ = AuthHeader;
}

test "Form extractor type" {
    const FormData = Form(struct { username: []const u8, password: []const u8 });
    _ = FormData;
}
