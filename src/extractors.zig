//! Type-safe request data extractors.
//! Path, Query, Body, and Header extraction into typed structs.

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
