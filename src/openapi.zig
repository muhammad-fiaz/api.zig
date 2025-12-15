//! OpenAPI 3.1 specification generator with automatic schema extraction from Zig types.

const std = @import("std");
const json = @import("json.zig");

/// OpenAPI specification builder.
pub const OpenAPI = struct {
    info: Info,
    servers: []const Server = &.{},
    paths: std.StringHashMap(PathItem),
    allocator: std.mem.Allocator,

    pub const Info = struct {
        title: []const u8,
        version: []const u8,
        description: ?[]const u8 = null,
        terms_of_service: ?[]const u8 = null,
        contact: ?Contact = null,
        license: ?License = null,
    };

    pub const Contact = struct {
        name: ?[]const u8 = null,
        url: ?[]const u8 = null,
        email: ?[]const u8 = null,
    };

    pub const License = struct {
        name: []const u8,
        url: ?[]const u8 = null,
    };

    pub const Server = struct {
        url: []const u8,
        description: ?[]const u8 = null,
    };

    pub const PathItem = struct {
        get: ?Operation = null,
        post: ?Operation = null,
        put: ?Operation = null,
        delete: ?Operation = null,
        patch: ?Operation = null,
        options: ?Operation = null,
        head: ?Operation = null,
    };

    pub const Operation = struct {
        summary: ?[]const u8 = null,
        description: ?[]const u8 = null,
        operation_id: ?[]const u8 = null,
        tags: []const []const u8 = &.{},
        parameters: []const Parameter = &.{},
        request_body: ?RequestBody = null,
        responses: std.StringHashMap(Response),
        deprecated: bool = false,
    };

    pub const Parameter = struct {
        name: []const u8,
        in: ParameterLocation,
        description: ?[]const u8 = null,
        required: bool = false,
        schema_type: []const u8 = "string",
    };

    pub const ParameterLocation = enum {
        query,
        path,
        header,
        cookie,
    };

    pub const RequestBody = struct {
        description: ?[]const u8 = null,
        content: std.StringHashMap(MediaType),
        required: bool = false,
    };

    pub const Response = struct {
        description: []const u8,
        content: ?std.StringHashMap(MediaType) = null,
    };

    pub const MediaType = struct {
        schema: ?Schema = null,
    };

    /// Initializes OpenAPI with info and allocator.
    pub fn init(allocator: std.mem.Allocator, info: Info) OpenAPI {
        return .{
            .info = info,
            .paths = std.StringHashMap(PathItem).init(allocator),
            .allocator = allocator,
        };
    }

    /// Releases resources.
    pub fn deinit(self: *OpenAPI) void {
        self.paths.deinit();
    }

    /// Extract path parameters from a path like "/users/{id}"
    fn extractPathParams(self: *OpenAPI, path: []const u8) ![]const Parameter {
        var params = std.ArrayListUnmanaged(Parameter){};

        var i: usize = 0;
        while (i < path.len) {
            if (path[i] == '{') {
                const start = i + 1;
                while (i < path.len and path[i] != '}') : (i += 1) {}
                if (i < path.len) {
                    const param_name = try self.allocator.dupe(u8, path[start..i]);
                    try params.append(self.allocator, Parameter{
                        .name = param_name,
                        .in = .path,
                        .required = true,
                        .schema_type = "string",
                        .description = null,
                    });
                }
            }
            i += 1;
        }

        return try params.toOwnedSlice(self.allocator);
    }

    /// Adds a route to the OpenAPI paths.
    pub fn addPath(self: *OpenAPI, method: []const u8, path: []const u8, summary: ?[]const u8, description: ?[]const u8, tags: []const []const u8, deprecated: bool) !void {
        // Convert path from {param} to OpenAPI format {param}
        const openapi_path = try self.allocator.dupe(u8, path);

        // Get or create PathItem for this path
        const result = try self.paths.getOrPut(openapi_path);
        if (!result.found_existing) {
            result.value_ptr.* = PathItem{};
        }

        // Create the operation with responses
        var responses = std.StringHashMap(Response).init(self.allocator);
        try responses.put("200", Response{ .description = "Successful response" });

        // Generate auto summary if not provided
        const auto_summary = if (summary) |s| s else try self.generateSummary(method, path);

        // Extract path parameters
        const path_params = try self.extractPathParams(path);

        const operation = Operation{
            .summary = auto_summary,
            .description = description,
            .tags = if (tags.len > 0) tags else &[_][]const u8{},
            .deprecated = deprecated,
            .responses = responses,
            .parameters = path_params,
        };

        // Set the operation for the correct method
        if (std.mem.eql(u8, method, "GET")) {
            result.value_ptr.*.get = operation;
        } else if (std.mem.eql(u8, method, "POST")) {
            result.value_ptr.*.post = operation;
        } else if (std.mem.eql(u8, method, "PUT")) {
            result.value_ptr.*.put = operation;
        } else if (std.mem.eql(u8, method, "DELETE")) {
            result.value_ptr.*.delete = operation;
        } else if (std.mem.eql(u8, method, "PATCH")) {
            result.value_ptr.*.patch = operation;
        } else if (std.mem.eql(u8, method, "OPTIONS")) {
            result.value_ptr.*.options = operation;
        } else if (std.mem.eql(u8, method, "HEAD")) {
            result.value_ptr.*.head = operation;
        }
    }

    /// Generate auto summary from method and path
    fn generateSummary(self: *OpenAPI, method: []const u8, path: []const u8) ![]const u8 {
        // Extract resource name from path
        var resource: []const u8 = "resource";
        var it = std.mem.splitScalar(u8, path, '/');
        while (it.next()) |segment| {
            if (segment.len > 0 and segment[0] != '{') {
                resource = segment;
            }
        }

        // Generate summary based on method
        if (std.mem.eql(u8, method, "GET")) {
            if (std.mem.indexOf(u8, path, "{")) |_| {
                return try std.fmt.allocPrint(self.allocator, "Get {s} by ID", .{resource});
            }
            return try std.fmt.allocPrint(self.allocator, "List {s}", .{resource});
        } else if (std.mem.eql(u8, method, "POST")) {
            return try std.fmt.allocPrint(self.allocator, "Create {s}", .{resource});
        } else if (std.mem.eql(u8, method, "PUT")) {
            return try std.fmt.allocPrint(self.allocator, "Update {s}", .{resource});
        } else if (std.mem.eql(u8, method, "DELETE")) {
            return try std.fmt.allocPrint(self.allocator, "Delete {s}", .{resource});
        } else if (std.mem.eql(u8, method, "PATCH")) {
            return try std.fmt.allocPrint(self.allocator, "Patch {s}", .{resource});
        }
        return try self.allocator.dupe(u8, path);
    }

    /// Generates the OpenAPI JSON specification.
    pub fn toJson(self: *const OpenAPI, allocator: std.mem.Allocator) ![]u8 {
        // Zig 0.15: use std.json.Stringify.valueAlloc with custom jsonStringify
        return std.json.Stringify.valueAlloc(allocator, self, .{ .whitespace = .indent_2 });
    }

    /// Custom JSON serialization for OpenAPI spec.
    pub fn jsonStringify(self: *const OpenAPI, jws: anytype) !void {
        try jws.beginObject();

        // openapi version
        try jws.objectField("openapi");
        try jws.write("3.1.0");

        // info
        try jws.objectField("info");
        try jws.write(self.info);

        // servers
        if (self.servers.len > 0) {
            try jws.objectField("servers");
            try jws.write(self.servers);
        }

        // paths - manually serialize StringHashMap
        try jws.objectField("paths");
        try jws.beginObject();
        var path_it = self.paths.iterator();
        while (path_it.next()) |entry| {
            try jws.objectField(entry.key_ptr.*);
            try serializePathItem(jws, entry.value_ptr);
        }
        try jws.endObject();

        try jws.endObject();
    }

    fn serializePathItem(jws: anytype, item: *const PathItem) !void {
        try jws.beginObject();
        if (item.get) |op| {
            try jws.objectField("get");
            try serializeOperation(jws, &op);
        }
        if (item.post) |op| {
            try jws.objectField("post");
            try serializeOperation(jws, &op);
        }
        if (item.put) |op| {
            try jws.objectField("put");
            try serializeOperation(jws, &op);
        }
        if (item.delete) |op| {
            try jws.objectField("delete");
            try serializeOperation(jws, &op);
        }
        if (item.patch) |op| {
            try jws.objectField("patch");
            try serializeOperation(jws, &op);
        }
        if (item.options) |op| {
            try jws.objectField("options");
            try serializeOperation(jws, &op);
        }
        if (item.head) |op| {
            try jws.objectField("head");
            try serializeOperation(jws, &op);
        }
        try jws.endObject();
    }

    fn serializeOperation(jws: anytype, op: *const Operation) !void {
        try jws.beginObject();
        if (op.summary) |s| {
            try jws.objectField("summary");
            try jws.write(s);
        }
        if (op.description) |d| {
            try jws.objectField("description");
            try jws.write(d);
        }
        if (op.operation_id) |id| {
            try jws.objectField("operationId");
            try jws.write(id);
        }
        if (op.tags.len > 0) {
            try jws.objectField("tags");
            try jws.write(op.tags);
        }
        if (op.parameters.len > 0) {
            try jws.objectField("parameters");
            try jws.beginArray();
            for (op.parameters) |param| {
                try jws.beginObject();
                try jws.objectField("name");
                try jws.write(param.name);
                try jws.objectField("in");
                try jws.write(switch (param.in) {
                    .path => "path",
                    .query => "query",
                    .header => "header",
                    .cookie => "cookie",
                });
                try jws.objectField("required");
                try jws.write(param.required);
                if (param.description) |desc| {
                    try jws.objectField("description");
                    try jws.write(desc);
                }
                try jws.objectField("schema");
                try jws.beginObject();
                try jws.objectField("type");
                try jws.write(param.schema_type);
                try jws.endObject();
                try jws.endObject();
            }
            try jws.endArray();
        }
        if (op.request_body) |rb| {
            try jws.objectField("requestBody");
            try serializeRequestBody(jws, &rb);
        }

        // responses - manually serialize StringHashMap
        try jws.objectField("responses");
        try jws.beginObject();
        var resp_it = op.responses.iterator();
        while (resp_it.next()) |entry| {
            try jws.objectField(entry.key_ptr.*);
            try serializeResponse(jws, entry.value_ptr);
        }
        try jws.endObject();

        if (op.deprecated) {
            try jws.objectField("deprecated");
            try jws.write(true);
        }
        try jws.endObject();
    }

    fn serializeRequestBody(jws: anytype, rb: *const RequestBody) !void {
        try jws.beginObject();
        if (rb.description) |d| {
            try jws.objectField("description");
            try jws.write(d);
        }

        // content - manually serialize StringHashMap
        try jws.objectField("content");
        try jws.beginObject();
        var content_it = rb.content.iterator();
        while (content_it.next()) |entry| {
            try jws.objectField(entry.key_ptr.*);
            try jws.write(entry.value_ptr.*);
        }
        try jws.endObject();

        if (rb.required) {
            try jws.objectField("required");
            try jws.write(true);
        }
        try jws.endObject();
    }

    fn serializeResponse(jws: anytype, resp: *const Response) !void {
        try jws.beginObject();
        try jws.objectField("description");
        try jws.write(resp.description);

        if (resp.content) |content| {
            try jws.objectField("content");
            try jws.beginObject();
            var content_it = content.iterator();
            while (content_it.next()) |entry| {
                try jws.objectField(entry.key_ptr.*);
                try jws.write(entry.value_ptr.*);
            }
            try jws.endObject();
        }
        try jws.endObject();
    }
};

/// JSON Schema definition for OpenAPI.
pub const Schema = struct {
    type_name: ?SchemaType = null,
    format: ?[]const u8 = null,
    description: ?[]const u8 = null,
    nullable: bool = false,
    // Use pointer to avoid infinite recursion in struct definition if not careful,
    // but here we use *const Schema for recursive types.
    // std.json.stringify might follow pointers automatically.
    properties: ?std.StringHashMap(*const Schema) = null,
    items: ?*const Schema = null,
    required_fields: []const []const u8 = &.{},
    enum_values: []const []const u8 = &.{},
    minimum: ?f64 = null,
    maximum: ?f64 = null,
    min_length: ?usize = null,
    max_length: ?usize = null,
    pattern: ?[]const u8 = null,
    default: ?[]const u8 = null,
    example: ?[]const u8 = null,

    pub fn jsonStringify(self: *const Schema, out: anytype) !void {
        try out.beginObject();
        if (self.type_name) |t| {
            try out.objectField("type");
            switch (t) {
                .string => try out.write("string"),
                .number => try out.write("number"),
                .integer => try out.write("integer"),
                .boolean => try out.write("boolean"),
                .array => try out.write("array"),
                .object => try out.write("object"),
                .null_type => try out.write("null"),
            }
        }
        if (self.format) |f| {
            try out.objectField("format");
            try out.write(f);
        }
        if (self.description) |d| {
            try out.objectField("description");
            try out.write(d);
        }
        if (self.properties) |props| {
            try out.objectField("properties");
            try out.beginObject();
            var it = props.iterator();
            while (it.next()) |entry| {
                try out.objectField(entry.key_ptr.*);
                try out.write(entry.value_ptr.*);
            }
            try out.endObject();
        }
        if (self.items) |it| {
            try out.objectField("items");
            try out.write(it);
        }
        try out.endObject();
    }

    pub const SchemaType = enum {
        string,
        number,
        integer,
        boolean,
        array,
        object,
        null_type,
    };

    /// Creates a string schema.
    pub fn string() Schema {
        return .{ .type_name = .string };
    }

    /// Creates an integer schema.
    pub fn integer() Schema {
        return .{ .type_name = .integer };
    }

    /// Creates a number schema.
    pub fn number() Schema {
        return .{ .type_name = .number };
    }

    /// Creates a boolean schema.
    pub fn boolean() Schema {
        return .{ .type_name = .boolean };
    }

    /// Creates an array schema.
    pub fn array(items_schema: *const Schema) Schema {
        return .{ .type_name = .array, .items = items_schema };
    }

    /// Creates an object schema.
    pub fn object() Schema {
        return .{ .type_name = .object };
    }
};

/// Generates a schema from a Zig type.
pub fn schemaFromType(comptime T: type) Schema {
    const info = @typeInfo(T);

    switch (info) {
        .int => return Schema.integer(),
        .float => return Schema.number(),
        .bool => return Schema.boolean(),
        .pointer => |p| {
            if (p.size == .slice and p.child == u8) {
                return Schema.string();
            }
            return Schema.object();
        },
        .@"struct" => return Schema.object(),
        .optional => |opt| {
            var schema = schemaFromType(opt.child);
            schema.nullable = true;
            return schema;
        },
        else => return Schema.object(),
    }
}

test "OpenAPI init" {
    var api = OpenAPI.init(std.testing.allocator, .{
        .title = "Test API",
        .version = "1.0.0",
    });
    defer api.deinit();
    try std.testing.expectEqualStrings("Test API", api.info.title);
}

test "schema from type" {
    const int_schema = schemaFromType(i32);
    try std.testing.expectEqual(Schema.SchemaType.integer, int_schema.type_name.?);

    const str_schema = schemaFromType([]const u8);
    try std.testing.expectEqual(Schema.SchemaType.string, str_schema.type_name.?);
}

test "OpenAPI toJson" {
    var api = OpenAPI.init(std.testing.allocator, .{
        .title = "Test API",
        .version = "1.0.0",
    });
    defer api.deinit();

    const json_str = try api.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json_str);

    try std.testing.expect(json_str.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"title\": \"Test API\"") != null);
}

test "schema builders" {
    const string_schema = Schema.string();
    try std.testing.expectEqual(Schema.SchemaType.string, string_schema.type_name.?);

    const int_schema = Schema.integer();
    try std.testing.expectEqual(Schema.SchemaType.integer, int_schema.type_name.?);
}
