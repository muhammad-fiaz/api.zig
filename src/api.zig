//! Zig API Framework
//!
//! High-performance HTTP framework with compile-time routing, automatic OpenAPI 3.1
//! generation, multi-threaded server, and comprehensive middleware support.

const std = @import("std");

// =============================================================================
// Core Application Types
// =============================================================================

/// Application orchestrator for routes, middleware, and server lifecycle.
pub const App = @import("app.zig").App;

/// Application initialization configuration.
pub const AppConfig = @import("app.zig").AppConfig;

/// Server runtime configuration.
pub const RunConfig = @import("app.zig").RunConfig;

// =============================================================================
// Routing
// =============================================================================

/// Compile-time router with pattern matching.
pub const Router = @import("router.zig");

/// Route configuration options.
pub const RouteConfig = Router.RouteConfig;

// =============================================================================
// HTTP Server and Client
// =============================================================================

/// Multi-threaded HTTP server.
pub const Server = @import("server.zig").Server;

/// Server configuration options.
pub const ServerConfig = @import("server.zig").ServerConfig;

/// HTTP client for outbound requests.
pub const Client = @import("client.zig").Client;

// =============================================================================
// Request and Response
// =============================================================================

/// HTTP response builder.
pub const Response = @import("response.zig").Response;

/// Parsed HTTP request.
pub const Request = @import("request.zig").Request;

/// Request context for handlers.
pub const Context = @import("context.zig").Context;

// =============================================================================
// HTTP Protocol Types
// =============================================================================

/// HTTP protocol types.
pub const http = @import("http.zig");

/// HTTP method enumeration.
pub const Method = http.Method;

/// HTTP status code enumeration.
pub const StatusCode = http.StatusCode;

/// Status code alias.
pub const Status = http.StatusCode;

/// HTTP headers collection.
pub const Headers = http.Headers;

// =============================================================================
// JSON Handling
// =============================================================================

/// JSON utilities.
pub const json = @import("json.zig");

// =============================================================================
// OpenAPI and Documentation
// =============================================================================

/// OpenAPI 3.1 specification generator.
pub const openapi = @import("openapi.zig");

/// OpenAPI specification builder.
pub const OpenAPI = openapi.OpenAPI;

/// JSON Schema type.
pub const Schema = openapi.Schema;

/// Schema generator from Zig types.
pub const schemaFromType = openapi.schemaFromType;

// =============================================================================
// Validation
// =============================================================================

/// Request validation utilities.
pub const validation = @import("validation.zig");

/// Validator type.
pub const Validator = validation.Validator;

// =============================================================================
// Extractors
// =============================================================================

/// Parameter extraction utilities.
pub const extractors = @import("extractors.zig");

/// Path parameter extractor.
pub const Path = extractors.Path;

/// Query parameter extractor.
pub const Query = extractors.Query;

/// Request body extractor.
pub const Body = extractors.Body;

/// Header value extractor.
pub const Header = extractors.Header;

// =============================================================================
// Static Files and Templates
// =============================================================================

/// Static file and template utilities.
pub const static = @import("static.zig");

/// Static file router.
pub const StaticFiles = static.StaticFiles;

/// Static file configuration.
pub const StaticConfig = static.StaticConfig;

/// HTML template engine.
pub const Templates = static.Templates;

/// HTML response helper.
pub const HTMLResponse = static.HTMLResponse;

/// HTML response with status.
pub const HTMLResponseWithStatus = static.HTMLResponseWithStatus;

/// File download response.
pub const FileResponse = static.FileResponse;

/// Streaming response.
pub const StreamingResponse = static.StreamingResponse;

// =============================================================================
// Logging
// =============================================================================

/// Thread-safe logging.
pub const logging = @import("logger.zig");

/// Logger type.
pub const Logger = logging.Logger;

/// Log level enumeration.
pub const LogLevel = logging.Level;

/// Global log function.
pub const log = logging.log;

// =============================================================================
// Middleware
// =============================================================================

/// Middleware utilities.
pub const middleware = @import("middleware.zig");

// =============================================================================
// Utilities
// =============================================================================

/// Version information.
pub const version = @import("version.zig");

/// Error reporting.
pub const report = @import("report.zig");

/// Response helpers.
pub const response = @import("response.zig");

// =============================================================================
// Schema Generation
// =============================================================================

/// Creates JSON Schema from a Zig struct type.
pub fn createSchema(comptime T: type) Schema {
    return openapi.schemaFromType(T);
}

/// Schema definition helpers.
pub const SchemaBuilder = struct {
    pub fn string() Schema {
        return .{ .type = "string" };
    }

    pub fn integer() Schema {
        return .{ .type = "integer" };
    }

    pub fn number() Schema {
        return .{ .type = "number" };
    }

    pub fn boolean() Schema {
        return .{ .type = "boolean" };
    }

    pub fn array(comptime items: Schema) Schema {
        return .{ .type = "array", .items = &items };
    }

    pub fn object() Schema {
        return .{ .type = "object" };
    }
};

// =============================================================================
// Tests
// =============================================================================

test {
    _ = @import("app.zig");
    _ = @import("router.zig");
    _ = @import("server.zig");
    _ = @import("response.zig");
    _ = @import("request.zig");
    _ = @import("context.zig");
    _ = @import("http.zig");
    _ = @import("json.zig");
    _ = @import("version.zig");
    _ = @import("report.zig");
    _ = @import("logger.zig");
    _ = @import("openapi.zig");
    _ = @import("extractors.zig");
    _ = @import("validation.zig");
    _ = @import("client.zig");
    _ = @import("middleware.zig");
    _ = @import("static.zig");
}
