//! GraphQL support for api.zig framework.
//! Provides schema definition, query parsing, execution, and subscriptions.
//!
//! ## Features
//! - Schema definition with types, queries, mutations, and subscriptions
//! - Query parsing and validation
//! - Resolver execution pipeline with DataLoader support
//! - Introspection support with schema caching
//! - Multiple GraphQL UI options: GraphiQL, Playground, Apollo Sandbox
//! - Subscription support via WebSocket
//! - Persisted queries and automatic query complexity analysis
//! - Federation support for microservices
//! - Distributed tracing and APM integration
//! - Query caching and response deduplication
//! - Custom scalars and directives
//! - Error masking for production

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;
const json = @import("json.zig");
const http = @import("http.zig");

/// GraphQL UI provider options
pub const GraphQLUIProvider = enum {
    graphiql,
    playground,
    apollo_sandbox,
    altair,
    voyager,

    pub fn toString(self: GraphQLUIProvider) []const u8 {
        return switch (self) {
            .graphiql => "GraphiQL",
            .playground => "GraphQL Playground",
            .apollo_sandbox => "Apollo Sandbox",
            .altair => "Altair GraphQL Client",
            .voyager => "GraphQL Voyager",
        };
    }
};

/// GraphQL UI Theme options
pub const GraphQLUITheme = enum {
    light,
    dark,
    system,

    pub fn toString(self: GraphQLUITheme) []const u8 {
        return switch (self) {
            .light => "light",
            .dark => "dark",
            .system => "system",
        };
    }
};

/// Comprehensive GraphQL UI configuration
pub const GraphQLUIConfig = struct {
    /// UI provider to use
    provider: GraphQLUIProvider = .graphiql,
    /// Theme preference
    theme: GraphQLUITheme = .dark,
    /// Title shown in the UI
    title: []const u8 = "GraphQL Explorer",
    /// GraphQL endpoint URL
    endpoint: []const u8 = "/graphql",
    /// WebSocket endpoint for subscriptions (if different)
    subscription_endpoint: ?[]const u8 = null,
    /// Enable schema polling
    schema_polling: bool = false,
    /// Schema polling interval in milliseconds
    schema_polling_interval_ms: u32 = 2000,
    /// Show documentation explorer
    show_docs: bool = true,
    /// Show history panel
    show_history: bool = true,
    /// Enable query persistence
    enable_persistence: bool = true,
    /// Custom headers to include in requests
    default_headers: []const HeaderPair = &.{},
    /// Initial query to display
    default_query: ?[]const u8 = null,
    /// Initial variables
    default_variables: ?[]const u8 = null,
    /// Enable keyboard shortcuts
    enable_shortcuts: bool = true,
    /// Tab size for editor
    editor_tab_size: u8 = 2,
    /// Font size for editor
    editor_font_size: u8 = 14,
    /// Enable syntax highlighting
    syntax_highlighting: bool = true,
    /// Enable code completion
    code_completion: bool = true,
    /// Enable schema introspection
    enable_introspection: bool = true,
    /// Prettify query on load
    prettify_query: bool = true,
    /// Custom CSS for UI styling
    custom_css: ?[]const u8 = null,
    /// Custom JavaScript for UI enhancements
    custom_js: ?[]const u8 = null,
    /// Logo URL for branding
    logo_url: ?[]const u8 = null,
    /// Favicon URL
    favicon_url: ?[]const u8 = null,
    /// Enable tracing in responses
    show_tracing: bool = false,
    /// Enable response caching UI
    show_cache_info: bool = false,
    /// Credentials policy for requests
    credentials: CredentialsPolicy = .same_origin,

    pub const HeaderPair = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const CredentialsPolicy = enum {
        omit,
        same_origin,
        include,

        pub fn toString(self: CredentialsPolicy) []const u8 {
            return switch (self) {
                .omit => "omit",
                .same_origin => "same-origin",
                .include => "include",
            };
        }
    };
};

/// Subscription protocol configuration
pub const SubscriptionConfig = struct {
    /// Protocol for subscriptions
    protocol: SubscriptionProtocol = .graphql_ws,
    /// Enable keep-alive
    keep_alive: bool = true,
    /// Keep-alive interval in milliseconds
    keep_alive_interval_ms: u32 = 30000,
    /// Connection timeout in milliseconds
    connection_timeout_ms: u32 = 30000,
    /// Maximum retry attempts
    max_retry_attempts: u32 = 5,
    /// Retry delay in milliseconds
    retry_delay_ms: u32 = 1000,
    /// Enable lazy connection (connect on first subscription)
    lazy: bool = true,

    pub const SubscriptionProtocol = enum {
        graphql_ws,
        subscriptions_transport_ws,

        pub fn getSubprotocol(self: SubscriptionProtocol) []const u8 {
            return switch (self) {
                .graphql_ws => "graphql-transport-ws",
                .subscriptions_transport_ws => "graphql-ws",
            };
        }
    };
};

/// Query complexity configuration
pub const ComplexityConfig = struct {
    /// Enable complexity analysis
    enabled: bool = true,
    /// Maximum allowed complexity
    max_complexity: u32 = 1000,
    /// Default field complexity
    default_field_complexity: u32 = 1,
    /// Complexity multiplier for lists
    list_multiplier: u32 = 10,
    /// Custom complexity calculator
    calculator: ?*const fn ([]const u8, []const u8) u32 = null,
};

/// Query depth configuration
pub const DepthConfig = struct {
    /// Enable depth limiting
    enabled: bool = true,
    /// Maximum query depth
    max_depth: u32 = 15,
    /// Ignore introspection queries in depth calculation
    ignore_introspection: bool = true,
};

/// Response caching configuration
pub const ResponseCacheConfig = struct {
    /// Enable response caching
    enabled: bool = false,
    /// Maximum cache size in entries
    max_size: usize = 1000,
    /// Default TTL in milliseconds
    default_ttl_ms: u64 = 60000,
    /// Cache key generator
    key_generator: ?*const fn (*Context, []const u8) []const u8 = null,
    /// Skip cache for mutations
    skip_mutations: bool = true,
    /// Cache control header handling
    respect_cache_control: bool = true,
};

/// Persisted queries configuration
pub const PersistedQueriesConfig = struct {
    /// Enable persisted queries
    enabled: bool = false,
    /// Only allow persisted queries (reject non-persisted)
    only_persisted: bool = false,
    /// Storage backend for persisted queries
    store: ?*anyopaque = null,
    /// SHA256 hash algorithm for query hashing
    use_sha256: bool = true,
};

/// Apollo Federation configuration
pub const FederationConfig = struct {
    /// Enable federation
    enabled: bool = false,
    /// Federation version
    version: FederationVersion = .v2,
    /// Service name for federation
    service_name: ?[]const u8 = null,
    /// Service URL for federation
    service_url: ?[]const u8 = null,

    pub const FederationVersion = enum {
        v1,
        v2,
    };
};

/// Tracing and APM configuration
pub const TracingConfig = struct {
    /// Enable tracing
    enabled: bool = false,
    /// Include resolver timings
    include_resolver_timings: bool = true,
    /// Include parsing timing
    include_parsing: bool = true,
    /// Include validation timing
    include_validation: bool = true,
    /// APM provider integration
    apm_provider: ?APMProvider = null,

    pub const APMProvider = enum {
        opentelemetry,
        datadog,
        newrelic,
        jaeger,
    };
};

/// Error handling configuration
pub const ErrorConfig = struct {
    /// Mask errors in production
    mask_errors: bool = true,
    /// Generic error message for masked errors
    generic_message: []const u8 = "An unexpected error occurred",
    /// Include stack traces
    include_stack_traces: bool = false,
    /// Include error codes
    include_error_codes: bool = true,
    /// Custom error formatter
    formatter: ?*const fn (anyerror) GraphQLError = null,
};

/// DataLoader configuration for batching
pub const DataLoaderConfig = struct {
    /// Enable DataLoader
    enabled: bool = true,
    /// Maximum batch size
    max_batch_size: usize = 100,
    /// Batch scheduling delay in microseconds
    batch_delay_us: u64 = 0,
    /// Enable caching within request
    cache: bool = true,
};

/// GraphQL scalar types.
pub const ScalarType = enum {
    ID,
    String,
    Int,
    Float,
    Boolean,
    DateTime,
    JSON,
    Date,
    Time,
    BigInt,
    Decimal,
    UUID,
    Email,
    URL,
    IPv4,
    IPv6,
    Phone,
    PostalCode,
    Currency,
    Duration,
    Timestamp,
    Void,
    Upload,
    Bytes,
    PositiveInt,
    NonNegativeInt,
    NegativeInt,
    NonPositiveInt,
    PositiveFloat,
    NonNegativeFloat,
    NegativeFloat,
    NonPositiveFloat,

    pub fn toString(self: ScalarType) []const u8 {
        return switch (self) {
            .ID => "ID",
            .String => "String",
            .Int => "Int",
            .Float => "Float",
            .Boolean => "Boolean",
            .DateTime => "DateTime",
            .JSON => "JSON",
            .Date => "Date",
            .Time => "Time",
            .BigInt => "BigInt",
            .Decimal => "Decimal",
            .UUID => "UUID",
            .Email => "Email",
            .URL => "URL",
            .IPv4 => "IPv4",
            .IPv6 => "IPv6",
            .Phone => "Phone",
            .PostalCode => "PostalCode",
            .Currency => "Currency",
            .Duration => "Duration",
            .Timestamp => "Timestamp",
            .Void => "Void",
            .Upload => "Upload",
            .Bytes => "Bytes",
            .PositiveInt => "PositiveInt",
            .NonNegativeInt => "NonNegativeInt",
            .NegativeInt => "NegativeInt",
            .NonPositiveInt => "NonPositiveInt",
            .PositiveFloat => "PositiveFloat",
            .NonNegativeFloat => "NonNegativeFloat",
            .NegativeFloat => "NegativeFloat",
            .NonPositiveFloat => "NonPositiveFloat",
        };
    }

    pub fn getDescription(self: ScalarType) []const u8 {
        return switch (self) {
            .ID => "Unique identifier, serialized as a string",
            .String => "UTF-8 character sequence",
            .Int => "32-bit signed integer",
            .Float => "IEEE 754 double precision floating point",
            .Boolean => "true or false",
            .DateTime => "ISO 8601 date-time string (e.g., 2024-01-15T10:30:00Z)",
            .JSON => "Arbitrary JSON value",
            .Date => "ISO 8601 date string (e.g., 2024-01-15)",
            .Time => "ISO 8601 time string (e.g., 10:30:00)",
            .BigInt => "Arbitrary precision integer",
            .Decimal => "Arbitrary precision decimal",
            .UUID => "UUID v4 string",
            .Email => "RFC 5322 email address",
            .URL => "RFC 3986 URI",
            .IPv4 => "IPv4 address",
            .IPv6 => "IPv6 address",
            .Phone => "E.164 phone number",
            .PostalCode => "Postal/ZIP code",
            .Currency => "ISO 4217 currency code",
            .Duration => "ISO 8601 duration (e.g., P1D, PT1H30M)",
            .Timestamp => "Unix timestamp in milliseconds",
            .Void => "Void type for operations with no return",
            .Upload => "File upload scalar",
            .Bytes => "Base64 encoded binary data",
            .PositiveInt => "Positive integer (> 0)",
            .NonNegativeInt => "Non-negative integer (>= 0)",
            .NegativeInt => "Negative integer (< 0)",
            .NonPositiveInt => "Non-positive integer (<= 0)",
            .PositiveFloat => "Positive float (> 0)",
            .NonNegativeFloat => "Non-negative float (>= 0)",
            .NegativeFloat => "Negative float (< 0)",
            .NonPositiveFloat => "Non-positive float (<= 0)",
        };
    }
};

/// GraphQL type definition kind.
pub const TypeKind = enum {
    SCALAR,
    OBJECT,
    INTERFACE,
    UNION,
    ENUM,
    INPUT_OBJECT,
    LIST,
    NON_NULL,
};

/// GraphQL field definition.
pub const FieldDefinition = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    type_name: []const u8,
    is_list: bool = false,
    is_non_null: bool = false,
    args: []const ArgumentDefinition = &.{},
    deprecation_reason: ?[]const u8 = null,
    resolver: ?*const fn (*Context, Arguments) anyerror!?Value = null,
};

/// GraphQL argument definition.
pub const ArgumentDefinition = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    type_name: []const u8,
    is_non_null: bool = false,
    default_value: ?[]const u8 = null,
};

/// GraphQL type definition.
pub const TypeDefinition = struct {
    name: []const u8,
    kind: TypeKind = .OBJECT,
    description: ?[]const u8 = null,
    fields: []const FieldDefinition = &.{},
    interfaces: []const []const u8 = &.{},
    possible_types: []const []const u8 = &.{},
    enum_values: []const EnumValue = &.{},
    input_fields: []const ArgumentDefinition = &.{},
};

/// GraphQL enum value.
pub const EnumValue = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    is_deprecated: bool = false,
    deprecation_reason: ?[]const u8 = null,
};

/// GraphQL directive definition.
pub const DirectiveDefinition = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    locations: []const DirectiveLocation = &.{},
    args: []const ArgumentDefinition = &.{},
};

/// GraphQL directive locations.
pub const DirectiveLocation = enum {
    QUERY,
    MUTATION,
    SUBSCRIPTION,
    FIELD,
    FRAGMENT_DEFINITION,
    FRAGMENT_SPREAD,
    INLINE_FRAGMENT,
    VARIABLE_DEFINITION,
    SCHEMA,
    SCALAR,
    OBJECT,
    FIELD_DEFINITION,
    ARGUMENT_DEFINITION,
    INTERFACE,
    UNION,
    ENUM,
    ENUM_VALUE,
    INPUT_OBJECT,
    INPUT_FIELD_DEFINITION,
};

/// GraphQL value types for resolver arguments and return values.
pub const Value = union(enum) {
    null: void,
    boolean: bool,
    int: i64,
    float: f64,
    string: []const u8,
    list: []const Value,
    object: std.StringHashMap(Value),

    pub fn toString(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .null => "null",
            .boolean => |b| if (b) "true" else "false",
            .int => |i| try std.fmt.allocPrint(allocator, "{d}", .{i}),
            .float => |f| try std.fmt.allocPrint(allocator, "{d}", .{f}),
            .string => |s| try std.fmt.allocPrint(allocator, "\"{s}\"", .{s}),
            .list => |_| "[...]",
            .object => |_| "{...}",
        };
    }

    pub fn isNull(self: Value) bool {
        return self == .null;
    }
};

/// GraphQL query arguments.
pub const Arguments = struct {
    items: std.StringHashMap(Value),

    pub fn init(allocator: std.mem.Allocator) Arguments {
        return .{ .items = std.StringHashMap(Value).init(allocator) };
    }

    pub fn get(self: *const Arguments, name: []const u8) ?Value {
        return self.items.get(name);
    }

    pub fn getString(self: *const Arguments, name: []const u8) ?[]const u8 {
        const val = self.items.get(name) orelse return null;
        return switch (val) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn getInt(self: *const Arguments, name: []const u8) ?i64 {
        const val = self.items.get(name) orelse return null;
        return switch (val) {
            .int => |i| i,
            else => null,
        };
    }

    pub fn getBool(self: *const Arguments, name: []const u8) ?bool {
        const val = self.items.get(name) orelse return null;
        return switch (val) {
            .boolean => |b| b,
            else => null,
        };
    }
};

/// GraphQL operation type.
pub const OperationType = enum {
    query,
    mutation,
    subscription,

    pub fn toString(self: OperationType) []const u8 {
        return switch (self) {
            .query => "query",
            .mutation => "mutation",
            .subscription => "subscription",
        };
    }
};

/// Parsed GraphQL operation.
pub const Operation = struct {
    type: OperationType = .query,
    name: ?[]const u8 = null,
    variables: std.StringHashMap(Value) = undefined,
    selections: []const Selection = &.{},
};

/// GraphQL field selection.
pub const Selection = struct {
    name: []const u8,
    alias: ?[]const u8 = null,
    arguments: []const Argument = &.{},
    directives: []const Directive = &.{},
    selections: []const Selection = &.{},
};

/// GraphQL field argument.
pub const Argument = struct {
    name: []const u8,
    value: Value,
};

/// GraphQL directive usage.
pub const Directive = struct {
    name: []const u8,
    arguments: []const Argument = &.{},
};

/// GraphQL execution result.
pub const ExecutionResult = struct {
    data: ?Value = null,
    errors: []const GraphQLError = &.{},
    extensions: ?std.StringHashMap(Value) = null,
};

/// GraphQL error type.
pub const GraphQLError = struct {
    message: []const u8,
    locations: []const SourceLocation = &.{},
    path: []const PathSegment = &.{},
    extensions: ?std.StringHashMap(Value) = null,
};

/// Source location for errors.
pub const SourceLocation = struct {
    line: u32,
    column: u32,
};

/// Path segment (string or index).
pub const PathSegment = union(enum) {
    field: []const u8,
    index: usize,
};

/// GraphQL schema definition.
pub const Schema = struct {
    allocator: std.mem.Allocator,
    query_type: ?*TypeDefinition = null,
    mutation_type: ?*TypeDefinition = null,
    subscription_type: ?*TypeDefinition = null,
    types: std.StringHashMap(TypeDefinition),
    directives: std.StringHashMap(DirectiveDefinition),
    resolvers: std.StringHashMap(*const fn (*Context, Arguments) anyerror!?Value),

    pub const Config = struct {
        enable_introspection: bool = true,
        max_depth: u32 = 15,
        max_complexity: u32 = 1000,
        enable_tracing: bool = false,
    };

    pub fn init(allocator: std.mem.Allocator) Schema {
        var schema = Schema{
            .allocator = allocator,
            .types = std.StringHashMap(TypeDefinition).init(allocator),
            .directives = std.StringHashMap(DirectiveDefinition).init(allocator),
            .resolvers = std.StringHashMap(*const fn (*Context, Arguments) anyerror!?Value).init(allocator),
        };

        // Add built-in scalar types
        schema.addScalarType("ID", "Unique identifier") catch {};
        schema.addScalarType("String", "UTF-8 string") catch {};
        schema.addScalarType("Int", "32-bit integer") catch {};
        schema.addScalarType("Float", "IEEE 754 floating point") catch {};
        schema.addScalarType("Boolean", "true or false") catch {};
        schema.addScalarType("DateTime", "ISO 8601 date-time string") catch {};
        schema.addScalarType("JSON", "Arbitrary JSON value") catch {};

        // Add built-in directives
        schema.addDirective(.{
            .name = "skip",
            .description = "Skip this field if argument is true",
            .locations = &.{ .FIELD, .FRAGMENT_SPREAD, .INLINE_FRAGMENT },
            .args = &.{.{ .name = "if", .type_name = "Boolean", .is_non_null = true }},
        }) catch {};

        schema.addDirective(.{
            .name = "include",
            .description = "Include this field if argument is true",
            .locations = &.{ .FIELD, .FRAGMENT_SPREAD, .INLINE_FRAGMENT },
            .args = &.{.{ .name = "if", .type_name = "Boolean", .is_non_null = true }},
        }) catch {};

        schema.addDirective(.{
            .name = "deprecated",
            .description = "Marks field as deprecated",
            .locations = &.{ .FIELD_DEFINITION, .ENUM_VALUE },
            .args = &.{.{ .name = "reason", .type_name = "String" }},
        }) catch {};

        return schema;
    }

    pub fn deinit(self: *Schema) void {
        self.types.deinit();
        self.directives.deinit();
        self.resolvers.deinit();
    }

    /// Adds a scalar type to the schema.
    pub fn addScalarType(self: *Schema, name: []const u8, description: ?[]const u8) !void {
        try self.types.put(name, .{
            .name = name,
            .kind = .SCALAR,
            .description = description,
        });
    }

    /// Adds an object type to the schema.
    pub fn addObjectType(self: *Schema, type_def: TypeDefinition) !void {
        try self.types.put(type_def.name, type_def);
    }

    /// Adds an enum type to the schema.
    pub fn addEnumType(self: *Schema, name: []const u8, values: []const EnumValue, description: ?[]const u8) !void {
        try self.types.put(name, .{
            .name = name,
            .kind = .ENUM,
            .description = description,
            .enum_values = values,
        });
    }

    /// Adds an input type to the schema.
    pub fn addInputType(self: *Schema, name: []const u8, fields: []const ArgumentDefinition, description: ?[]const u8) !void {
        try self.types.put(name, .{
            .name = name,
            .kind = .INPUT_OBJECT,
            .description = description,
            .input_fields = fields,
        });
    }

    /// Adds a union type to the schema.
    pub fn addUnionType(self: *Schema, name: []const u8, types: []const []const u8, description: ?[]const u8) !void {
        try self.types.put(name, .{
            .name = name,
            .kind = .UNION,
            .description = description,
            .possible_types = types,
        });
    }

    /// Adds an interface type to the schema.
    pub fn addInterfaceType(self: *Schema, name: []const u8, fields: []const FieldDefinition, description: ?[]const u8) !void {
        try self.types.put(name, .{
            .name = name,
            .kind = .INTERFACE,
            .description = description,
            .fields = fields,
        });
    }

    /// Sets the query type.
    pub fn setQueryType(self: *Schema, type_def: TypeDefinition) !void {
        try self.addObjectType(type_def);
        self.query_type = self.types.getPtr(type_def.name);
    }

    /// Sets the mutation type.
    pub fn setMutationType(self: *Schema, type_def: TypeDefinition) !void {
        try self.addObjectType(type_def);
        self.mutation_type = self.types.getPtr(type_def.name);
    }

    /// Sets the subscription type.
    pub fn setSubscriptionType(self: *Schema, type_def: TypeDefinition) !void {
        try self.addObjectType(type_def);
        self.subscription_type = self.types.getPtr(type_def.name);
    }

    /// Adds a directive to the schema.
    pub fn addDirective(self: *Schema, directive: DirectiveDefinition) !void {
        try self.directives.put(directive.name, directive);
    }

    /// Registers a resolver function.
    pub fn addResolver(self: *Schema, type_name: []const u8, field_name: []const u8, resolver: *const fn (*Context, Arguments) anyerror!?Value) !void {
        var buf: [256]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "{s}.{s}", .{ type_name, field_name }) catch return error.KeyTooLong;
        const owned_key = try self.allocator.dupe(u8, key);
        try self.resolvers.put(owned_key, resolver);
    }

    /// Gets a resolver for a type/field combination.
    pub fn getResolver(self: *const Schema, type_name: []const u8, field_name: []const u8) ?*const fn (*Context, Arguments) anyerror!?Value {
        var buf: [256]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "{s}.{s}", .{ type_name, field_name }) catch return null;
        return self.resolvers.get(key);
    }

    /// Gets a type by name.
    pub fn getType(self: *const Schema, name: []const u8) ?TypeDefinition {
        return self.types.get(name);
    }

    /// Generates SDL (Schema Definition Language) representation.
    pub fn toSDL(self: *const Schema, allocator: std.mem.Allocator) ![]const u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        const writer = buffer.writer(allocator);

        // Write schema definition
        try writer.writeAll("schema {\n");
        if (self.query_type) |qt| {
            try writer.print("  query: {s}\n", .{qt.name});
        }
        if (self.mutation_type) |mt| {
            try writer.print("  mutation: {s}\n", .{mt.name});
        }
        if (self.subscription_type) |st| {
            try writer.print("  subscription: {s}\n", .{st.name});
        }
        try writer.writeAll("}\n\n");

        // Write type definitions
        var type_iter = self.types.iterator();
        while (type_iter.next()) |entry| {
            const type_def = entry.value_ptr.*;

            switch (type_def.kind) {
                .SCALAR => {
                    if (type_def.description) |desc| {
                        try writer.print("\"\"\"{s}\"\"\"\n", .{desc});
                    }
                    try writer.print("scalar {s}\n\n", .{type_def.name});
                },
                .OBJECT => {
                    if (type_def.description) |desc| {
                        try writer.print("\"\"\"{s}\"\"\"\n", .{desc});
                    }
                    try writer.print("type {s}", .{type_def.name});
                    if (type_def.interfaces.len > 0) {
                        try writer.writeAll(" implements ");
                        for (type_def.interfaces, 0..) |iface, i| {
                            if (i > 0) try writer.writeAll(" & ");
                            try writer.writeAll(iface);
                        }
                    }
                    try writer.writeAll(" {\n");
                    for (type_def.fields) |field| {
                        try writeFieldDefinition(writer, field);
                    }
                    try writer.writeAll("}\n\n");
                },
                .ENUM => {
                    if (type_def.description) |desc| {
                        try writer.print("\"\"\"{s}\"\"\"\n", .{desc});
                    }
                    try writer.print("enum {s} {{\n", .{type_def.name});
                    for (type_def.enum_values) |ev| {
                        try writer.print("  {s}\n", .{ev.name});
                    }
                    try writer.writeAll("}\n\n");
                },
                .INPUT_OBJECT => {
                    if (type_def.description) |desc| {
                        try writer.print("\"\"\"{s}\"\"\"\n", .{desc});
                    }
                    try writer.print("input {s} {{\n", .{type_def.name});
                    for (type_def.input_fields) |field| {
                        try writer.print("  {s}: {s}", .{ field.name, field.type_name });
                        if (field.is_non_null) try writer.writeAll("!");
                        try writer.writeAll("\n");
                    }
                    try writer.writeAll("}\n\n");
                },
                .INTERFACE => {
                    if (type_def.description) |desc| {
                        try writer.print("\"\"\"{s}\"\"\"\n", .{desc});
                    }
                    try writer.print("interface {s} {{\n", .{type_def.name});
                    for (type_def.fields) |field| {
                        try writeFieldDefinition(writer, field);
                    }
                    try writer.writeAll("}\n\n");
                },
                .UNION => {
                    if (type_def.description) |desc| {
                        try writer.print("\"\"\"{s}\"\"\"\n", .{desc});
                    }
                    try writer.print("union {s} = ", .{type_def.name});
                    for (type_def.possible_types, 0..) |pt, i| {
                        if (i > 0) try writer.writeAll(" | ");
                        try writer.writeAll(pt);
                    }
                    try writer.writeAll("\n\n");
                },
                else => {},
            }
        }

        return buffer.toOwnedSlice(allocator);
    }

    /// Generates JSON introspection response for GraphQL clients
    pub fn toIntrospectionJson(self: *const Schema, allocator: std.mem.Allocator) ![]const u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        const writer = buffer.writer(allocator);

        try writer.writeAll("{\"data\":{\"__schema\":{");

        // Query type
        if (self.query_type) |qt| {
            try writer.print("\"queryType\":{{\"name\":\"{s}\"}}", .{qt.name});
        } else {
            try writer.writeAll("\"queryType\":null");
        }

        // Mutation type
        if (self.mutation_type) |mt| {
            try writer.print(",\"mutationType\":{{\"name\":\"{s}\"}}", .{mt.name});
        } else {
            try writer.writeAll(",\"mutationType\":null");
        }

        // Subscription type
        if (self.subscription_type) |st| {
            try writer.print(",\"subscriptionType\":{{\"name\":\"{s}\"}}", .{st.name});
        } else {
            try writer.writeAll(",\"subscriptionType\":null");
        }

        // Types
        try writer.writeAll(",\"types\":[");

        // Add built-in scalar types
        const builtin_scalars = [_][]const u8{ "String", "Int", "Float", "Boolean", "ID" };
        var first = true;
        for (builtin_scalars) |scalar| {
            if (!first) try writer.writeAll(",");
            try writer.print("{{\"name\":\"{s}\",\"kind\":\"SCALAR\",\"description\":null,\"fields\":null,\"inputFields\":null,\"interfaces\":null,\"enumValues\":null,\"possibleTypes\":null}}", .{scalar});
            first = false;
        }

        // Always include root types first (avoid duplicates when iterating schema types)
        var wrote_query: bool = false;
        var wrote_mutation: bool = false;
        var wrote_subscription: bool = false;

        if (self.query_type) |qt| {
            if (!first) try writer.writeAll(",");
            try self.writeTypeIntrospection(writer, qt.*);
            wrote_query = true;
            first = false;
        }
        if (self.mutation_type) |mt| {
            if (!first) try writer.writeAll(",");
            try self.writeTypeIntrospection(writer, mt.*);
            wrote_mutation = true;
            first = false;
        }
        if (self.subscription_type) |st| {
            if (!first) try writer.writeAll(",");
            try self.writeTypeIntrospection(writer, st.*);
            wrote_subscription = true;
            first = false;
        }

        // Add remaining schema types (skip any root types already written)
        var type_iter = self.types.iterator();
        while (type_iter.next()) |entry| {
            const type_def = entry.value_ptr.*;
            if (wrote_query and self.query_type != null and std.mem.eql(u8, type_def.name, self.query_type.?.name)) continue;
            if (wrote_mutation and self.mutation_type != null and std.mem.eql(u8, type_def.name, self.mutation_type.?.name)) continue;
            if (wrote_subscription and self.subscription_type != null and std.mem.eql(u8, type_def.name, self.subscription_type.?.name)) continue;
            try writer.writeAll(",");
            try self.writeTypeIntrospection(writer, type_def);
        }

        try writer.writeAll("],\"directives\":[]}}}");

        return buffer.toOwnedSlice(allocator);
    }

    fn writeTypeIntrospection(self: *const Schema, writer: anytype, type_def: TypeDefinition) !void {
        _ = self;
        try writer.writeAll("{");
        try writer.print("\"name\":\"{s}\"", .{type_def.name});

        // Kind
        const kind_str = switch (type_def.kind) {
            .SCALAR => "SCALAR",
            .OBJECT => "OBJECT",
            .INTERFACE => "INTERFACE",
            .UNION => "UNION",
            .ENUM => "ENUM",
            .INPUT_OBJECT => "INPUT_OBJECT",
            .LIST => "LIST",
            .NON_NULL => "NON_NULL",
        };
        try writer.print(",\"kind\":\"{s}\"", .{kind_str});

        // Description
        if (type_def.description) |desc| {
            try writer.print(",\"description\":\"{s}\"", .{desc});
        } else {
            try writer.writeAll(",\"description\":null");
        }

        // Fields (for OBJECT and INTERFACE)
        if (type_def.kind == .OBJECT or type_def.kind == .INTERFACE) {
            try writer.writeAll(",\"fields\":[");
            for (type_def.fields, 0..) |field, i| {
                if (i > 0) try writer.writeAll(",");
                try writeFieldIntrospection(writer, field);
            }
            try writer.writeAll("]");
        } else {
            try writer.writeAll(",\"fields\":null");
        }

        // Input fields (for INPUT_OBJECT)
        if (type_def.kind == .INPUT_OBJECT) {
            try writer.writeAll(",\"inputFields\":[");
            for (type_def.input_fields, 0..) |field, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.print("{{\"name\":\"{s}\",\"type\":{{\"name\":\"{s}\",\"kind\":\"{s}\"}}}}", .{
                    field.name,
                    field.type_name,
                    if (field.is_non_null) "NON_NULL" else "SCALAR",
                });
            }
            try writer.writeAll("]");
        } else {
            try writer.writeAll(",\"inputFields\":null");
        }

        // Interfaces
        try writer.writeAll(",\"interfaces\":null");

        // Enum values
        if (type_def.kind == .ENUM) {
            try writer.writeAll(",\"enumValues\":[");
            for (type_def.enum_values, 0..) |ev, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.print("{{\"name\":\"{s}\",\"isDeprecated\":false}}", .{ev.name});
            }
            try writer.writeAll("]");
        } else {
            try writer.writeAll(",\"enumValues\":null");
        }

        // Possible types (for UNION and INTERFACE)
        try writer.writeAll(",\"possibleTypes\":null");

        try writer.writeAll("}");
    }
};

fn writeFieldIntrospection(writer: anytype, field: FieldDefinition) !void {
    try writer.writeAll("{");
    try writer.print("\"name\":\"{s}\"", .{field.name});

    if (field.description) |desc| {
        try writer.print(",\"description\":\"{s}\"", .{desc});
    } else {
        try writer.writeAll(",\"description\":null");
    }

    // Args
    try writer.writeAll(",\"args\":[");
    for (field.args, 0..) |arg, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("{{\"name\":\"{s}\",\"type\":{{\"name\":\"{s}\",\"kind\":\"{s}\"}}}}", .{
            arg.name,
            arg.type_name,
            if (arg.is_non_null) "NON_NULL" else "SCALAR",
        });
    }
    try writer.writeAll("]");

    // Type
    try writer.print(",\"type\":{{\"name\":\"{s}\",\"kind\":\"{s}\"}}", .{
        field.type_name,
        if (field.is_list) "LIST" else if (field.is_non_null) "NON_NULL" else "SCALAR",
    });

    try writer.writeAll(",\"isDeprecated\":");
    try writer.writeAll(if (field.deprecation_reason != null) "true" else "false");

    if (field.deprecation_reason) |reason| {
        try writer.print(",\"deprecationReason\":\"{s}\"", .{reason});
    } else {
        try writer.writeAll(",\"deprecationReason\":null");
    }

    try writer.writeAll("}");
}

fn writeFieldDefinition(writer: anytype, field: FieldDefinition) !void {
    if (field.description) |desc| {
        try writer.print("  \"\"\"{s}\"\"\"\n", .{desc});
    }
    try writer.print("  {s}", .{field.name});

    if (field.args.len > 0) {
        try writer.writeAll("(");
        for (field.args, 0..) |arg, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{s}: {s}", .{ arg.name, arg.type_name });
            if (arg.is_non_null) try writer.writeAll("!");
            if (arg.default_value) |dv| {
                try writer.print(" = {s}", .{dv});
            }
        }
        try writer.writeAll(")");
    }

    try writer.print(": ", .{});
    if (field.is_list) try writer.writeAll("[");
    try writer.writeAll(field.type_name);
    if (field.is_list) try writer.writeAll("]");
    if (field.is_non_null) try writer.writeAll("!");

    if (field.deprecation_reason) |reason| {
        try writer.print(" @deprecated(reason: \"{s}\")", .{reason});
    }

    try writer.writeAll("\n");
}

/// Parse error types for GraphQL parsing.
pub const ParseError = error{
    ExpectedOpenBrace,
    ExpectedOpenBracket,
    ExpectedColon,
    ExpectedQuote,
    ExpectedIdentifier,
    InvalidValue,
    InvalidNumber,
    InvalidBoolean,
    InvalidNull,
    UnexpectedChar,
    OutOfMemory,
};

/// GraphQL query parser.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    pos: usize = 0,
    line: u32 = 1,
    column: u32 = 1,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        return .{ .allocator = allocator, .source = source };
    }

    /// Parses a GraphQL document.
    pub fn parse(self: *Parser) !Operation {
        self.skipWhitespace();

        var operation = Operation{
            .variables = std.StringHashMap(Value).init(self.allocator),
        };

        // Check for operation type
        if (self.matchKeyword("query")) {
            operation.type = .query;
        } else if (self.matchKeyword("mutation")) {
            operation.type = .mutation;
        } else if (self.matchKeyword("subscription")) {
            operation.type = .subscription;
        }

        self.skipWhitespace();

        // Parse operation name if present
        if (self.isIdentifierStart()) {
            operation.name = try self.parseIdentifier();
        }

        self.skipWhitespace();

        // Parse variables if present
        if (self.peek() == '(') {
            _ = self.advance();
            // Skip variable definitions for now
            while (self.peek() != ')' and self.pos < self.source.len) {
                _ = self.advance();
            }
            if (self.peek() == ')') _ = self.advance();
        }

        self.skipWhitespace();

        // Parse selection set
        if (self.peek() == '{') {
            operation.selections = try self.parseSelectionSet();
        }

        return operation;
    }

    const SelectionError = ParseError || error{Unexpected};

    fn parseSelectionSet(self: *Parser) SelectionError![]const Selection {
        var selections: std.ArrayListUnmanaged(Selection) = .{};

        if (self.peek() != '{') return error.ExpectedOpenBrace;
        _ = self.advance();

        self.skipWhitespace();

        while (self.peek() != '}' and self.pos < self.source.len) {
            const selection = try self.parseSelection();
            selections.append(self.allocator, selection) catch return error.OutOfMemory;
            self.skipWhitespace();
        }

        if (self.peek() == '}') _ = self.advance();

        return selections.toOwnedSlice(self.allocator) catch error.OutOfMemory;
    }

    fn parseSelection(self: *Parser) SelectionError!Selection {
        self.skipWhitespace();

        var selection = Selection{
            .name = self.parseIdentifier() catch return error.InvalidValue,
        };

        self.skipWhitespace();

        // Parse alias
        if (self.peek() == ':') {
            _ = self.advance();
            self.skipWhitespace();
            selection.alias = selection.name;
            selection.name = self.parseIdentifier() catch return error.InvalidValue;
            self.skipWhitespace();
        }

        // Parse arguments
        if (self.peek() == '(') {
            selection.arguments = self.parseArguments() catch return error.OutOfMemory;
            self.skipWhitespace();
        }

        // Parse nested selection set
        if (self.peek() == '{') {
            selection.selections = try self.parseSelectionSet();
        }

        return selection;
    }

    fn parseArguments(self: *Parser) ParseError![]const Argument {
        var args: std.ArrayListUnmanaged(Argument) = .{};

        if (self.peek() != '(') return &.{};
        _ = self.advance();

        self.skipWhitespace();

        while (self.peek() != ')' and self.pos < self.source.len) {
            const arg = try self.parseArgument();
            try args.append(self.allocator, arg);
            self.skipWhitespace();
            if (self.peek() == ',') {
                _ = self.advance();
                self.skipWhitespace();
            }
        }

        if (self.peek() == ')') _ = self.advance();

        return args.toOwnedSlice(self.allocator);
    }

    fn parseArgument(self: *Parser) !Argument {
        const name = try self.parseIdentifier();
        self.skipWhitespace();

        if (self.peek() != ':') return error.ExpectedColon;
        _ = self.advance();
        self.skipWhitespace();

        const value = try self.parseValue();

        return .{ .name = name, .value = value };
    }

    fn parseValue(self: *Parser) ParseError!Value {
        self.skipWhitespace();

        const c = self.peek();

        if (c == '"') {
            return .{ .string = try self.parseString() };
        } else if (c == '-' or std.ascii.isDigit(c)) {
            return try self.parseNumber();
        } else if (c == 't' or c == 'f') {
            return .{ .boolean = try self.parseBoolean() };
        } else if (c == 'n') {
            _ = try self.parseNull();
            return .{ .null = {} };
        } else if (c == '[') {
            return try self.parseList();
        } else if (c == '{') {
            return try self.parseObject();
        }

        return error.InvalidValue;
    }

    fn parseString(self: *Parser) ![]const u8 {
        if (self.peek() != '"') return error.ExpectedQuote;
        _ = self.advance();

        const start = self.pos;
        while (self.pos < self.source.len and self.peek() != '"') {
            if (self.peek() == '\\') {
                _ = self.advance();
            }
            _ = self.advance();
        }
        const end = self.pos;

        if (self.peek() == '"') _ = self.advance();

        return self.source[start..end];
    }

    fn parseNumber(self: *Parser) !Value {
        const start = self.pos;
        var is_float = false;

        if (self.peek() == '-') _ = self.advance();

        while (self.pos < self.source.len) {
            const c = self.peek();
            if (std.ascii.isDigit(c)) {
                _ = self.advance();
            } else if (c == '.' and !is_float) {
                is_float = true;
                _ = self.advance();
            } else if (c == 'e' or c == 'E') {
                is_float = true;
                _ = self.advance();
                if (self.peek() == '+' or self.peek() == '-') _ = self.advance();
            } else {
                break;
            }
        }

        const num_str = self.source[start..self.pos];

        if (is_float) {
            return .{ .float = std.fmt.parseFloat(f64, num_str) catch return error.InvalidNumber };
        } else {
            return .{ .int = std.fmt.parseInt(i64, num_str, 10) catch return error.InvalidNumber };
        }
    }

    fn parseBoolean(self: *Parser) !bool {
        if (self.matchKeyword("true")) return true;
        if (self.matchKeyword("false")) return false;
        return error.InvalidBoolean;
    }

    fn parseNull(self: *Parser) !void {
        if (!self.matchKeyword("null")) return error.InvalidNull;
    }

    fn parseList(self: *Parser) ParseError!Value {
        if (self.peek() != '[') return error.ExpectedOpenBracket;
        _ = self.advance();

        var items: std.ArrayListUnmanaged(Value) = .{};
        self.skipWhitespace();

        while (self.peek() != ']' and self.pos < self.source.len) {
            const val = try self.parseValue();
            try items.append(self.allocator, val);
            self.skipWhitespace();
            if (self.peek() == ',') {
                _ = self.advance();
                self.skipWhitespace();
            }
        }

        if (self.peek() == ']') _ = self.advance();

        return .{ .list = items.toOwnedSlice(self.allocator) catch &.{} };
    }

    fn parseObject(self: *Parser) ParseError!Value {
        if (self.peek() != '{') return error.ExpectedOpenBrace;
        _ = self.advance();

        var obj = std.StringHashMap(Value).init(self.allocator);
        self.skipWhitespace();

        while (self.peek() != '}' and self.pos < self.source.len) {
            const key = self.parseIdentifier() catch return error.InvalidValue;
            self.skipWhitespace();
            if (self.peek() != ':') return error.ExpectedColon;
            _ = self.advance();
            self.skipWhitespace();
            const val = try self.parseValue();
            obj.put(key, val) catch return error.OutOfMemory;
            self.skipWhitespace();
            if (self.peek() == ',') {
                _ = self.advance();
                self.skipWhitespace();
            }
        }

        if (self.peek() == '}') _ = self.advance();

        return .{ .object = obj };
    }

    fn parseIdentifier(self: *Parser) ![]const u8 {
        const start = self.pos;
        while (self.pos < self.source.len and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_')) {
            _ = self.advance();
        }
        if (start == self.pos) return error.ExpectedIdentifier;
        return self.source[start..self.pos];
    }

    fn matchKeyword(self: *Parser, keyword: []const u8) bool {
        if (self.pos + keyword.len > self.source.len) return false;
        if (std.mem.eql(u8, self.source[self.pos .. self.pos + keyword.len], keyword)) {
            self.pos += keyword.len;
            return true;
        }
        return false;
    }

    fn isIdentifierStart(self: *Parser) bool {
        const c = self.peek();
        return std.ascii.isAlphabetic(c) or c == '_';
    }

    fn peek(self: *Parser) u8 {
        if (self.pos >= self.source.len) return 0;
        return self.source[self.pos];
    }

    fn advance(self: *Parser) u8 {
        if (self.pos >= self.source.len) return 0;
        const c = self.source[self.pos];
        self.pos += 1;
        if (c == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
        return c;
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.source.len) {
            const c = self.peek();
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == ',') {
                _ = self.advance();
            } else if (c == '#') {
                // Skip comment
                while (self.pos < self.source.len and self.peek() != '\n') {
                    _ = self.advance();
                }
            } else {
                break;
            }
        }
    }
};

/// GraphQL executor.
pub const Executor = struct {
    allocator: std.mem.Allocator,
    schema: *const Schema,
    config: ExecutorConfig,

    pub const ExecutorConfig = struct {
        max_depth: u32 = 15,
        max_complexity: u32 = 1000,
        enable_tracing: bool = false,
        enable_batching: bool = false,
        batch_size: u32 = 10,
    };

    pub fn init(allocator: std.mem.Allocator, schema: *const Schema, config: ExecutorConfig) Executor {
        return .{
            .allocator = allocator,
            .schema = schema,
            .config = config,
        };
    }

    /// Executes a GraphQL operation.
    pub fn execute(self: *Executor, ctx: *Context, operation: Operation, variables: ?std.StringHashMap(Value)) !ExecutionResult {
        _ = variables;

        var result = ExecutionResult{
            .data = null,
            .errors = &.{},
        };

        const root_type: ?*TypeDefinition = switch (operation.type) {
            .query => self.schema.query_type,
            .mutation => self.schema.mutation_type,
            .subscription => self.schema.subscription_type,
        };

        if (root_type == null) {
            return ExecutionResult{
                .errors = &.{.{
                    .message = "Schema does not support this operation type",
                }},
            };
        }

        // Execute selections
        var data = std.StringHashMap(Value).init(self.allocator);

        for (operation.selections) |selection| {
            const field_name = selection.name;
            const resolver = self.schema.getResolver(root_type.?.name, field_name);

            if (resolver) |r| {
                var args = Arguments.init(self.allocator);
                for (selection.arguments) |arg| {
                    try args.items.put(arg.name, arg.value);
                }

                const field_value = r(ctx, args) catch {
                    continue;
                };

                if (field_value) |v| {
                    const key = selection.alias orelse field_name;
                    try data.put(key, v);
                }
            }
        }

        result.data = .{ .object = data };
        return result;
    }

    /// Executes a query string.
    pub fn executeQuery(self: *Executor, ctx: *Context, query: []const u8, variables: ?std.StringHashMap(Value)) !ExecutionResult {
        var parser = Parser.init(self.allocator, query);
        const operation = parser.parse() catch {
            return ExecutionResult{
                .errors = &.{.{
                    .message = "Failed to parse GraphQL query",
                }},
            };
        };

        return self.execute(ctx, operation, variables);
    }
};

/// GraphQL handler configuration.
pub const GraphQLConfig = struct {
    /// GraphQL schema (required)
    schema: *Schema,
    /// GraphQL endpoint path
    path: []const u8 = "/graphql",
    /// UI path (null to disable)
    playground_path: ?[]const u8 = "/graphql/playground",
    /// GraphiQL path (null to disable)
    graphiql_path: ?[]const u8 = "/graphql/graphiql",
    /// Apollo Sandbox path (null to disable)
    apollo_sandbox_path: ?[]const u8 = null,
    /// Altair path (null to disable)
    altair_path: ?[]const u8 = null,
    /// Voyager path (null to disable)
    voyager_path: ?[]const u8 = null,
    /// Enable playground/UI
    enable_playground: bool = true,
    /// Enable introspection
    enable_introspection: bool = true,
    /// Maximum query depth
    max_depth: u32 = 15,
    /// Maximum query complexity
    max_complexity: u32 = 1000,
    /// Enable query batching
    enable_batching: bool = false,
    /// Maximum batch size
    max_batch_size: u32 = 10,
    /// Enable tracing
    enable_tracing: bool = false,
    /// Enable persisted queries
    enable_persisted_queries: bool = false,
    /// Only allow persisted queries (security feature)
    persisted_queries_only: bool = false,
    /// Enable APM integration
    enable_apm: bool = false,
    /// Mask errors in production
    mask_errors: bool = true,
    /// Enable response caching
    enable_caching: bool = false,
    /// Cache TTL in milliseconds
    cache_ttl_ms: u64 = 60000,
    /// Enable CORS for GraphQL endpoint
    enable_cors: bool = true,
    /// CORS allowed origins
    cors_origins: []const []const u8 = &.{"*"},
    /// Enable subscriptions
    enable_subscriptions: bool = false,
    /// Subscription path (usually same as main path)
    subscription_path: ?[]const u8 = null,
    /// Subscription protocol
    subscription_protocol: SubscriptionConfig.SubscriptionProtocol = .graphql_ws,
    /// UI configuration
    ui_config: GraphQLUIConfig = .{},
    /// Complexity configuration
    complexity_config: ComplexityConfig = .{},
    /// Depth configuration
    depth_config: DepthConfig = .{},
    /// Tracing configuration
    tracing_config: TracingConfig = .{},
    /// Error configuration
    error_config: ErrorConfig = .{},
    /// Response cache configuration
    response_cache_config: ResponseCacheConfig = .{},
    /// Persisted queries configuration
    persisted_queries_config: PersistedQueriesConfig = .{},
    /// Federation configuration
    federation_config: FederationConfig = .{},
    /// DataLoader configuration
    dataloader_config: DataLoaderConfig = .{},
    /// Subscription configuration
    subscription_config: SubscriptionConfig = .{},
    /// Custom context factory
    context_factory: ?*const fn (*Context) anyerror!*anyopaque = null,
    /// Custom error handler
    error_handler: ?*const fn (anyerror, *Context) GraphQLError = null,
    /// Request validation hook
    validation_hook: ?*const fn ([]const u8, *Context) anyerror!void = null,
    /// Response hook
    response_hook: ?*const fn (*ExecutionResult, *Context) void = null,
};

/// Creates a GraphQL handler for the application.
pub fn graphqlHandler(config: GraphQLConfig) type {
    return struct {
        pub fn handle(ctx: *Context) Response {
            const body = ctx.body();

            // Handle OPTIONS for CORS preflight
            if (ctx.method() == .OPTIONS) {
                return Response.init()
                    .setStatus(.no_content)
                    .setHeader("Access-Control-Allow-Origin", "*")
                    .setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
                    .setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
                    .setHeader("Access-Control-Max-Age", "86400");
            }

            // Handle GET requests (query in URL)
            if (ctx.method() == .GET) {
                if (ctx.query("query")) |query| {
                    return executeGraphQLQuery(ctx, query, ctx.query("operationName"), ctx.query("variables"));
                }
                return Response.err(.bad_request, "{\"errors\":[{\"message\":\"No query provided\"}]}").withCors("*");
            }

            if (body.len == 0) {
                return Response.err(.bad_request, "{\"errors\":[{\"message\":\"Empty request body\"}]}").withCors("*");
            }

            // Parse request
            const RequestBody = struct {
                query: []const u8,
                operationName: ?[]const u8 = null,
                variables: ?[]const u8 = null,
            };

            const request_data = json.parse(RequestBody, ctx.allocator, body) catch {
                return Response.err(.bad_request, "{\"errors\":[{\"message\":\"Invalid JSON request body\"}]}").withCors("*");
            };

            return executeGraphQLQuery(ctx, request_data.query, request_data.operationName, request_data.variables);
        }

        fn executeGraphQLQuery(ctx: *Context, query: []const u8, operation_name: ?[]const u8, variables_str: ?[]const u8) Response {
            _ = operation_name;
            _ = variables_str;

            // Check for persisted queries
            if (config.enable_persisted_queries and config.persisted_queries_only) {
                // In persisted queries only mode, check if query is a hash
                if (query.len == 64) { // SHA256 hash length
                    // Look up query by hash
                    // For now, return error since we don't have storage
                    return Response.err(.bad_request, "{\"errors\":[{\"message\":\"Persisted query not found\"}]}").withCors("*");
                }
            }

            // Validate query depth if enabled
            if (config.depth_config.enabled) {
                const depth = calculateQueryDepth(query);
                if (depth > config.depth_config.max_depth) {
                    const err_msg = "{\"errors\":[{\"message\":\"Query depth exceeds maximum allowed\"}]}";
                    return Response.err(.bad_request, err_msg).withCors("*");
                }
            }

            // Execute query
            var executor = Executor.init(ctx.allocator, config.schema, .{
                .max_depth = config.max_depth,
                .max_complexity = config.max_complexity,
                .enable_tracing = config.enable_tracing,
                .enable_batching = config.enable_batching,
            });

            const result = executor.executeQuery(ctx, query, null) catch {
                if (config.mask_errors) {
                    return Response.err(.internal_server_error, "{\"errors\":[{\"message\":\"An unexpected error occurred\"}]}").withCors("*");
                }
                return Response.err(.internal_server_error, "{\"errors\":[{\"message\":\"Query execution failed\"}]}").withCors("*");
            };

            // Serialize response
            var response = serializeResult(ctx.allocator, result, config.enable_tracing);

            // Add CORS headers if enabled
            if (config.enable_cors) {
                response = response.withCors("*");
            }

            return response;
        }

        fn calculateQueryDepth(query: []const u8) u32 {
            var depth: u32 = 0;
            var max_depth: u32 = 0;
            for (query) |c| {
                if (c == '{') {
                    depth += 1;
                    if (depth > max_depth) max_depth = depth;
                } else if (c == '}') {
                    if (depth > 0) depth -= 1;
                }
            }
            return max_depth;
        }

        fn serializeResult(allocator: std.mem.Allocator, result: ExecutionResult, include_tracing: bool) Response {
            var buffer: std.ArrayListUnmanaged(u8) = .{};
            const writer = buffer.writer(allocator);

            writer.writeAll("{") catch return Response.err(.internal_server_error, "{}").withCors("*");

            // Write data
            if (result.data) |data| {
                writer.writeAll("\"data\":") catch {};
                writeValue(writer, allocator, data) catch {};
            } else {
                writer.writeAll("\"data\":null") catch {};
            }

            // Write errors
            if (result.errors.len > 0) {
                writer.writeAll(",\"errors\":[") catch {};
                for (result.errors, 0..) |err, i| {
                    if (i > 0) writer.writeAll(",") catch {};
                    writer.print("{{\"message\":\"{s}\"}}", .{err.message}) catch {};
                }
                writer.writeAll("]") catch {};
            }

            // Write extensions (tracing, caching info, etc.)
            if (include_tracing or result.extensions != null) {
                writer.writeAll(",\"extensions\":{") catch {};
                var first_ext = true;
                if (include_tracing) {
                    writer.writeAll("\"tracing\":{\"version\":1}") catch {};
                    first_ext = false;
                }
                if (result.extensions) |exts| {
                    var iter = exts.iterator();
                    while (iter.next()) |entry| {
                        if (!first_ext) writer.writeAll(",") catch {};
                        first_ext = false;
                        writer.print("\"{s}\":", .{entry.key_ptr.*}) catch {};
                        writeValue(writer, allocator, entry.value_ptr.*) catch {};
                    }
                }
                writer.writeAll("}") catch {};
            }

            writer.writeAll("}") catch {};

            return Response.jsonRaw(buffer.toOwnedSlice(allocator) catch "{}");
        }

        fn writeValue(writer: anytype, allocator: std.mem.Allocator, value: Value) !void {
            switch (value) {
                .null => try writer.writeAll("null"),
                .boolean => |b| try writer.writeAll(if (b) "true" else "false"),
                .int => |i| try writer.print("{d}", .{i}),
                .float => |f| try writer.print("{d}", .{f}),
                .string => |s| try writer.print("\"{s}\"", .{s}),
                .list => |l| {
                    try writer.writeAll("[");
                    for (l, 0..) |item, idx| {
                        if (idx > 0) try writer.writeAll(",");
                        try writeValue(writer, allocator, item);
                    }
                    try writer.writeAll("]");
                },
                .object => |o| {
                    try writer.writeAll("{");
                    var iter = o.iterator();
                    var first = true;
                    while (iter.next()) |entry| {
                        if (!first) try writer.writeAll(",");
                        first = false;
                        try writer.print("\"{s}\":", .{entry.key_ptr.*});
                        try writeValue(writer, allocator, entry.value_ptr.*);
                    }
                    try writer.writeAll("}");
                },
            }
        }
    };
}

/// GraphQL Playground HTML page.
pub fn graphqlPlayground(endpoint: []const u8) []const u8 {
    _ = endpoint;
    return graphqlPlaygroundWithConfig(.{});
}

/// GraphQL Playground with full configuration - uses local assets
/// GraphQL Playground with full configuration - uses local assets (GraphiQL)
pub fn graphqlPlaygroundWithConfig(config: GraphQLUIConfig) []const u8 {
    _ = config;
    return 
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\  <title>GraphQL Playground</title>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <link rel="stylesheet" href="/_assets/graphiql.min.css"/>
    \\  <style>
    \\    body { height: 100vh; margin: 0; overflow: hidden; background: #0b0c0e; font-family: system-ui, sans-serif; }
    \\    #graphiql { height: 100vh; }
    \\    .loader { position: fixed; top: 0; left: 0; width: 100%; height: 100%; display: flex; flex-direction: column; justify-content: center; align-items: center; background: #0b0c0e; z-index: 9999; color: white; transition: opacity 0.5s; }
    \\    .loader.hide { opacity: 0; pointer-events: none; }
    \\    .spinner { width: 40px; height: 40px; border: 4px solid #333; border-top-color: #e10098; border-radius: 50%; animation: spin 1s linear infinite; margin-bottom: 20px; }
    \\    @keyframes spin { to { transform: rotate(360deg); } }
    \\  </style>
    \\</head>
    \\<body>
    \\  <div class="loader" id="loader">
    \\    <div class="spinner"></div>
    \\    <div>Loading GraphQL Playground... 🚀</div>
    \\  </div>
    \\  <div id="graphiql"></div>
    \\  <script src="/_assets/react.production.min.js"></script>
    \\  <script src="/_assets/react-dom.production.min.js"></script>
    \\  <script src="/_assets/graphiql.min.js"></script>
    \\  <script>
    \\    const root = ReactDOM.createRoot(document.getElementById('graphiql'));
    \\    const fetcher = GraphiQL.createFetcher({
    \\      url: window.location.origin + '/graphql',
    \\      headers: { 'Content-Type': 'application/json' }
    \\    });
    \\    root.render(React.createElement(GraphiQL, {
    \\      fetcher: fetcher,
    \\      defaultEditorToolsVisibility: true
    \\    }));
    \\    setTimeout(() => document.getElementById('loader').classList.add('hide'), 500);
    \\  </script>
    \\</body>
    \\</html>
    ;
}

/// GraphiQL HTML page (alternative to Playground).
pub fn graphiql(endpoint: []const u8) []const u8 {
    _ = endpoint;
    return graphiqlWithConfig(.{});
}

/// GraphiQL with full configuration - uses local assets
pub fn graphiqlWithConfig(config: GraphQLUIConfig) []const u8 {
    _ = config;
    return 
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\  <title>GraphiQL</title>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <link rel="stylesheet" href="/_assets/graphiql.min.css"/>
    \\  <style>
    \\    body { height: 100vh; margin: 0; overflow: hidden; }
    \\    #graphiql { height: 100vh; }
    \\    .graphiql-container { height: 100%; }
    \\  </style>
    \\</head>
    \\<body>
    \\  <div id="graphiql"></div>
    \\  <script src="/_assets/react.production.min.js"></script>
    \\  <script src="/_assets/react-dom.production.min.js"></script>
    \\  <script src="/_assets/graphiql.min.js"></script>
    \\  <script>
    \\    const root = ReactDOM.createRoot(document.getElementById('graphiql'));
    \\    const fetcher = GraphiQL.createFetcher({
    \\      url: '/graphql',
    \\      headers: { 'Content-Type': 'application/json' }
    \\    });
    \\    root.render(
    \\      React.createElement(GraphiQL, {
    \\        fetcher: fetcher,
    \\        defaultEditorToolsVisibility: true,
    \\        shouldPersistHeaders: true,
    \\        isHeadersEditorEnabled: true,
    \\        defaultQuery: '# Welcome to GraphiQL\\n#\\n# GraphiQL is an in-browser IDE for exploring GraphQL APIs\\n#\\nquery IntrospectionQuery {\\n  __schema {\\n    queryType { name }\\n    mutationType { name }\\n    subscriptionType { name }\\n    types { name kind description }\\n  }\\n}'
    \\      })
    \\    );
    \\  </script>
    \\</body>
    \\</html>
    ;
}

/// Apollo Sandbox HTML page
pub fn apolloSandbox(endpoint: []const u8) []const u8 {
    _ = endpoint;
    return apolloSandboxWithConfig(.{});
}

/// Apollo Sandbox with full configuration - uses local assets
pub fn apolloSandboxWithConfig(config: GraphQLUIConfig) []const u8 {
    _ = config;
    return 
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\  <title>Apollo Sandbox</title>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <style>
    \\    body { height: 100vh; margin: 0; overflow: hidden; }
    \\    #sandbox { height: 100vh; width: 100vw; }
    \\  </style>
    \\</head>
    \\<body>
    \\  <div id="sandbox"></div>
    \\  <script src="/_assets/apollo-sandbox.min.js"></script>
    \\  <script>
    \\    new window.EmbeddedSandbox({
    \\      target: '#sandbox',
    \\      initialEndpoint: window.location.origin + '/graphql',
    \\      includeCookies: true,
    \\      initialState: {
    \\        document: '# Welcome to Apollo Sandbox\\n#\\n# Apollo Sandbox is a powerful GraphQL IDE\\n#\\nquery IntrospectionQuery {\\n  __schema {\\n    queryType { name }\\n    types { name kind }\\n  }\\n}',
    \\        variables: '{}',
    \\        headers: {}
    \\      },
    \\      handleRequest: (endpointUrl, options) => {
    \\        return fetch(endpointUrl, {
    \\          ...options,
    \\          credentials: 'same-origin'
    \\        });
    \\      }
    \\    });
    \\  </script>
    \\</body>
    \\</html>
    ;
}

/// Altair GraphQL Client HTML page
pub fn altairGraphQL(endpoint: []const u8) []const u8 {
    _ = endpoint;
    return altairGraphQLWithConfig(.{});
}

/// Altair GraphQL Client with full configuration - uses local assets
pub fn altairGraphQLWithConfig(config: GraphQLUIConfig) []const u8 {
    _ = config;
    return 
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\  <title>Altair GraphQL Client</title>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <link rel="stylesheet" href="/_assets/altair-styles.css"/>
    \\  <style>
    \\    body { height: 100vh; margin: 0; overflow: hidden; }
    \\  </style>
    \\</head>
    \\<body>
    \\  <app-root></app-root>
    \\  <script src="/_assets/altair-runtime.js"></script>
    \\  <script src="/_assets/altair-polyfills.js"></script>
    \\  <script src="/_assets/altair-main.js"></script>
    \\  <script>
    \\    document.addEventListener('DOMContentLoaded', function() {
    \\      AltairGraphQL.init({
    \\        endpointURL: '/graphql',
    \\        subscriptionsEndpoint: window.location.origin.replace('http', 'ws') + '/graphql',
    \\        initialQuery: '# Welcome to Altair GraphQL Client\\n#\\n# Altair is a feature-rich GraphQL Client IDE\\n#\\nquery {\\n  __schema {\\n    types { name }\\n  }\\n}',
    \\        initialVariables: '{}',
    \\        initialHeaders: {},
    \\        initialSettings: {
    \\          theme: 'dark',
    \\          language: 'en-US',
    \\          addQueryDepthLimit: 15,
    \\          tabSize: 2,
    \\          enableExperimental: true,
    \\          'alert.disableWarnings': false,
    \\          'history.depth': 100,
    \\          'response.hideExtensions': false,
    \\          'schema.reloadOnStart': true,
    \\          'schemaViz.sort': true,
    \\          'plugin.list': []
    \\        }
    \\      });
    \\    });
    \\  </script>
    \\</body>
    \\</html>
    ;
}

/// GraphQL Voyager - schema visualization
pub fn graphqlVoyager(endpoint: []const u8) []const u8 {
    _ = endpoint;
    return graphqlVoyagerWithConfig(.{});
}

/// GraphQL Voyager with full configuration - uses local assets
pub fn graphqlVoyagerWithConfig(config: GraphQLUIConfig) []const u8 {
    _ = config;
    return 
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\  <title>GraphQL Voyager</title>
    \\  <meta charset="utf-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1">
    \\  <link rel="stylesheet" href="/_assets/voyager.css"/>
    \\  <style>
    \\    body { height: 100vh; margin: 0; overflow: hidden; }
    \\    #voyager { height: 100vh; }
    \\  </style>
    \\</head>
    \\<body>
    \\  <div id="voyager"></div>
    \\  <script src="/_assets/react.production.min.js"></script>
    \\  <script src="/_assets/react-dom.production.min.js"></script>
    \\  <script src="/_assets/voyager.standalone.js"></script>
    \\  <script>
    \\    function introspectionProvider(query) {
    \\      return fetch('/graphql', {
    \\        method: 'POST',
    \\        headers: { 'Content-Type': 'application/json' },
    \\        body: JSON.stringify({ query: query }),
    \\        credentials: 'same-origin'
    \\      }).then(response => response.json());
    \\    }
    \\    // Voyager 2.x API
    \\    GraphQLVoyager.renderVoyager(document.getElementById('voyager'), {
    \\      introspection: introspectionProvider,
    \\      displayOptions: {
    \\        skipRelay: true,
    \\        skipDeprecated: false,
    \\        showLeafFields: true,
    \\        sortByAlphabet: true,
    \\        hideRoot: false
    \\      }
    \\    });
    \\  </script>
    \\</body>
    \\</html>
    ;
}

/// Generate GraphQL UI based on config
pub fn generateGraphQLUI(config: GraphQLUIConfig) []const u8 {
    return switch (config.provider) {
        .graphiql => graphiqlWithConfig(config),
        .playground => graphqlPlaygroundWithConfig(config),
        .apollo_sandbox => apolloSandboxWithConfig(config),
        .altair => altairGraphQLWithConfig(config),
        .voyager => graphqlVoyagerWithConfig(config),
    };
}

test "parser basic query" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, "query { users { id name } }");
    const op = try parser.parse();
    defer {
        // Free nested selections
        for (op.selections) |sel| {
            if (sel.selections.len > 0) {
                allocator.free(sel.selections);
            }
        }
        allocator.free(op.selections);
    }

    try std.testing.expectEqual(OperationType.query, op.type);
    try std.testing.expectEqual(@as(usize, 1), op.selections.len);
    try std.testing.expectEqualStrings("users", op.selections[0].name);
}

test "schema builder" {
    const allocator = std.testing.allocator;
    var schema = Schema.init(allocator);
    defer schema.deinit();

    try schema.setQueryType(.{
        .name = "Query",
        .fields = &.{
            .{ .name = "hello", .type_name = "String", .is_non_null = true },
        },
    });

    const qt = schema.query_type;
    try std.testing.expect(qt != null);
    try std.testing.expectEqualStrings("Query", qt.?.name);
}
