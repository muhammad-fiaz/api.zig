//! High-performance HTTP framework for Zig with compile-time routing,
//! automatic OpenAPI 3.1 generation, and multi-threaded request handling.
//!
//! API.zig provides a production-ready foundation for building RESTful APIs
//! with features including middleware pipelines, authentication, validation,
//! rate limiting, CORS, and comprehensive request/response handling.
//!
//! ## Features
//! - Compile-time route registration with type-safe extractors
//! - Automatic OpenAPI 3.1 specification generation
//! - Thread-pool based request handling with optimized I/O
//! - Full middleware pipeline (CORS, Auth, Rate Limiting, Security Headers)
//! - JSON serialization/deserialization with validation
//! - Static file serving with SPA support
//! - HTTP client for outbound requests
//! - Structured logging with ANSI color support
//! - GraphQL support with schema definition and resolvers
//! - WebSocket support for real-time communication
//! - Metrics and health monitoring (Prometheus-compatible)
//! - Caching with LRU eviction and TTL expiration
//! - Session management with CSRF protection

const std = @import("std");

/// Centralized framework configuration combining all module configs.
pub const FrameworkConfig = struct {
    app: AppConfig = .{},
    server: ServerConfig = .{},
    cors: CorsConfig = .{},
    rate_limit: RateLimitConfig = .{},
    security: SecurityHeadersConfig = .{},
    compression: CompressionConfig = .{},
    logging: LogConfig = .{},
    graphql: GraphQLConfig = .{},
    websocket: WebSocketConfig = .{},
    metrics: MetricsConfig = .{},
    cache: CacheConfig = .{},
    session: SessionConfig = .{},
};

// Core Application
pub const App = @import("app.zig").App;
pub const AppConfig = @import("app.zig").AppConfig;
pub const RunConfig = @import("app.zig").RunConfig;

// Routing
pub const Router = @import("router.zig");
pub const RouteConfig = Router.RouteConfig;
pub const Route = Router.Route;
pub const MatchResult = Router.MatchResult;

// Server
pub const Server = @import("server.zig").Server;
pub const ServerConfig = @import("server.zig").ServerConfig;

// HTTP Client
pub const Client = @import("client.zig").Client;
pub const ClientConfig = @import("client.zig").Client.Config;
pub const ClientResponse = @import("client.zig").Client.Response;
pub const RequestBuilder = @import("client.zig").Client.RequestBuilder;

// Request/Response
pub const Response = @import("response.zig").Response;
pub const Request = @import("request.zig").Request;
pub const Context = @import("context.zig").Context;

// HTTP Protocol
pub const http = @import("http.zig");
pub const Method = http.Method;
pub const StatusCode = http.StatusCode;
pub const Status = http.StatusCode;
pub const Headers = http.Headers;
pub const ContentType = http.Headers.ContentTypes;
pub const getMimeType = http.getMimeType;

// JSON Utilities
pub const json = @import("json.zig");
pub const parseJson = json.parse;
pub const parseValue = json.parseValue;
pub const stringifyJson = json.stringify;
pub const toJson = json.toJson;
pub const toPrettyJson = json.toPrettyJson;
pub const isValidJson = json.isValid;
pub const escapeJsonString = json.escapeString;

// OpenAPI Specification
pub const openapi = @import("openapi.zig");
pub const OpenAPI = openapi.OpenAPI;
pub const Schema = openapi.Schema;
pub const schemaFromType = openapi.schemaFromType;

// Request Validation
pub const validation = @import("validation.zig");
pub const Validator = validation.Validator;
pub const ValidationResult = validation.ValidationResult;
pub const ValidationError = validation.ValidationError;
pub const isEmail = validation.isEmail;
pub const isUrl = validation.isUrl;
pub const isUuid = validation.isUuid;
pub const isAlpha = validation.isAlpha;
pub const isAlphanumeric = validation.isAlphanumeric;
pub const isNumeric = validation.isNumeric;
pub const isDate = validation.isDate;
pub const isIpv4 = validation.isIpv4;
pub const isPhone = validation.isPhone;
pub const isCreditCard = validation.isCreditCard;
pub const isNotEmpty = validation.isNotEmpty;
pub const isLengthBetween = validation.isLengthBetween;
pub const isHex = validation.isHex;
pub const isOneOf = validation.isOneOf;
pub const inRange = validation.inRange;

// Parameter Extractors
pub const extractors = @import("extractors.zig");
pub const Path = extractors.Path;
pub const Query = extractors.Query;
pub const Body = extractors.Body;
pub const Header = extractors.Header;
pub const CookieExtractor = extractors.Cookie;
pub const Cookies = extractors.Cookies;
pub const Form = extractors.Form;
pub const State = extractors.State;
pub const ClientInfo = extractors.ClientInfo;
pub const Depends = extractors.Depends;
pub const Authorization = extractors.Authorization;
pub const UserAgent = extractors.UserAgent;
pub const Accept = extractors.Accept;
pub const RequestId = extractors.RequestId;
pub const ForwardedFor = extractors.ForwardedFor;

// Static Files and Templates
pub const static = @import("static.zig");
pub const StaticFiles = static.StaticFiles;
pub const StaticConfig = static.StaticConfig;
pub const Templates = static.Templates;
pub const HTMLResponse = static.HTMLResponse;
pub const HTMLResponseWithStatus = static.HTMLResponseWithStatus;
pub const FileResponse = static.FileResponse;
pub const StreamingResponse = static.StreamingResponse;

// Logging
pub const logging = @import("logger.zig");
pub const Logger = logging.Logger;
pub const LogLevel = logging.Level;
pub const Color = logging.Color;

// Middleware
pub const middleware = @import("middleware.zig");
pub const CorsConfig = middleware.CorsConfig;
pub const AuthConfig = middleware.AuthConfig;
pub const AuthScheme = middleware.AuthScheme;
pub const AuthCredentials = middleware.AuthCredentials;
pub const RateLimitConfig = middleware.RateLimitConfig;
pub const SecurityHeadersConfig = middleware.SecurityHeadersConfig;
pub const CompressionConfig = middleware.CompressionConfig;
pub const LogConfig = middleware.LogConfig;
pub const RequestIdConfig = middleware.RequestIdConfig;
pub const RecoveryConfig = middleware.RecoveryConfig;
pub const TrustedHostConfig = middleware.TrustedHostConfig;
pub const TimeoutConfig = middleware.TimeoutConfig;

// Middleware Functions
pub const cors = middleware.cors;
pub const auth = middleware.auth;
pub const basicAuth = middleware.basicAuth;
pub const rateLimit = middleware.rateLimit;
pub const securityHeaders = middleware.securityHeaders;
pub const defaultSecurityHeaders = middleware.defaultSecurityHeaders;
pub const logger = middleware.logger;
pub const loggerWithConfig = middleware.loggerWithConfig;
pub const requestId = middleware.requestId;
pub const requestIdWithConfig = middleware.requestIdWithConfig;
pub const recover = middleware.recover;
pub const recoverWithConfig = middleware.recoverWithConfig;
pub const trustedHost = middleware.trustedHost;
pub const trustedHostMiddleware = middleware.trustedHostMiddleware;
pub const compressionWithConfig = middleware.compressionWithConfig;
pub const gzip = middleware.gzip;
pub const etag = middleware.etag;
pub const timeout = middleware.timeout;
// GraphQL Middleware
pub const graphqlMiddleware = middleware.graphqlMiddleware;
pub const graphqlCors = middleware.graphqlCors;
pub const graphqlRateLimit = middleware.graphqlRateLimit;
pub const graphqlTracing = middleware.graphqlTracing;
pub const GraphQLMiddlewareConfig = middleware.GraphQLMiddlewareConfig;
pub const GraphQLCorsConfig = middleware.GraphQLCorsConfig;
pub const GraphQLRateLimitConfig = middleware.GraphQLRateLimitConfig;
pub const GraphQLTracingConfig = middleware.GraphQLTracingConfig;
pub const FederationMiddlewareConfig = middleware.FederationConfig;

// Version and Reporting
pub const version = @import("version.zig");
pub const report = @import("report.zig");

// GraphQL Support
pub const graphql = @import("graphql.zig");
pub const GraphQLSchema = graphql.Schema;
pub const GraphQLConfig = graphql.GraphQLConfig;
pub const GraphQLValue = graphql.Value;
pub const GraphQLArguments = graphql.Arguments;
pub const GraphQLParser = graphql.Parser;
pub const GraphQLExecutor = graphql.Executor;
pub const GraphQLTypeDefinition = graphql.TypeDefinition;
pub const GraphQLFieldDefinition = graphql.FieldDefinition;
pub const GraphQLScalarType = graphql.ScalarType;
pub const graphqlHandler = graphql.graphqlHandler;
pub const graphqlPlayground = graphql.graphqlPlayground;
pub const graphiql = graphql.graphiql;
// GraphQL UI Providers
pub const GraphQLUIProvider = graphql.GraphQLUIProvider;
pub const GraphQLUITheme = graphql.GraphQLUITheme;
pub const GraphQLUIConfig = graphql.GraphQLUIConfig;
pub const apolloSandbox = graphql.apolloSandbox;
pub const altairGraphQL = graphql.altairGraphQL;
pub const graphqlVoyager = graphql.graphqlVoyager;
pub const generateGraphQLUI = graphql.generateGraphQLUI;
// GraphQL UI with config
pub const graphqlPlaygroundWithConfig = graphql.graphqlPlaygroundWithConfig;
pub const graphiqlWithConfig = graphql.graphiqlWithConfig;
pub const apolloSandboxWithConfig = graphql.apolloSandboxWithConfig;
pub const altairGraphQLWithConfig = graphql.altairGraphQLWithConfig;
pub const graphqlVoyagerWithConfig = graphql.graphqlVoyagerWithConfig;
// GraphQL Advanced Config Types
pub const SubscriptionConfig = graphql.SubscriptionConfig;
pub const ComplexityConfig = graphql.ComplexityConfig;
pub const DepthConfig = graphql.DepthConfig;
pub const ResponseCacheConfig = graphql.ResponseCacheConfig;
pub const PersistedQueriesConfig = graphql.PersistedQueriesConfig;
pub const FederationConfig = graphql.FederationConfig;
pub const TracingConfig = graphql.TracingConfig;
pub const ErrorConfig = graphql.ErrorConfig;
pub const DataLoaderConfig = graphql.DataLoaderConfig;
// GraphQL Types
pub const GraphQLOperation = graphql.Operation;
pub const GraphQLOperationType = graphql.OperationType;
pub const GraphQLSelection = graphql.Selection;
pub const GraphQLDirective = graphql.Directive;
pub const GraphQLExecutionResult = graphql.ExecutionResult;
pub const GraphQLError = graphql.GraphQLError;
pub const GraphQLTypeKind = graphql.TypeKind;
pub const GraphQLDirectiveLocation = graphql.DirectiveLocation;
pub const GraphQLDirectiveDefinition = graphql.DirectiveDefinition;
pub const GraphQLArgumentDefinition = graphql.ArgumentDefinition;
pub const GraphQLEnumValue = graphql.EnumValue;

// WebSocket Support
pub const websocket = @import("websocket.zig");
pub const WebSocketConfig = websocket.WebSocketConfig;
pub const WebSocketHub = websocket.Hub;
pub const WebSocketConnection = websocket.Connection;
pub const WebSocketFrame = websocket.Frame;
pub const WebSocketMessage = websocket.Message;
pub const WebSocketOpcode = websocket.Opcode;
pub const WebSocketCloseCode = websocket.CloseCode;
pub const WebSocketHandshake = websocket.Handshake;
pub const WebSocketEventHandler = websocket.EventHandler;

// Metrics and Monitoring
pub const metrics = @import("metrics.zig");
pub const MetricsConfig = metrics.RegistryConfig;
pub const MetricsRegistry = metrics.Registry;
pub const MetricsCounter = metrics.Counter;
pub const MetricsGauge = metrics.Gauge;
pub const MetricsHistogram = metrics.Histogram;
pub const HealthChecker = metrics.HealthChecker;
pub const HealthStatus = metrics.HealthStatus;
pub const HealthConfig = metrics.HealthChecker.HealthConfig;
pub const HealthChecks = metrics.Checks;
pub const metricsMiddleware = metrics.metricsMiddleware;

// Caching
pub const cache = @import("cache.zig");
pub const Cache = cache.Cache;
pub const CacheConfig = cache.CacheConfig;
pub const CacheStats = cache.CacheStats;
pub const ResponseCache = cache.ResponseCache;
pub const CacheControl = cache.CacheControl;
pub const ETag = cache.ETag;
pub const cacheMiddleware = cache.cacheMiddleware;

// Session Management
pub const session = @import("session.zig");
pub const Session = session.Session;
pub const SessionConfig = session.SessionConfig;
pub const SessionManager = session.Manager;
pub const SessionStore = session.Store;
pub const MemorySessionStore = session.MemoryStore;
pub const CSRF = session.CSRF;
pub const sessionMiddleware = session.sessionMiddleware;

// Response Module
pub const response = @import("response.zig");
pub const Cookie = response.Cookie;

// Response Helpers
pub const ok = response.ok;
pub const created = response.created;
pub const noContent = response.noContent;
pub const badRequest = response.badRequest;
pub const unauthorized = response.unauthorized;
pub const forbidden = response.forbidden;
pub const notFound = response.notFound;
pub const internalError = response.internalError;

/// Creates JSON Schema from a Zig struct type for OpenAPI documentation.
pub fn createSchema(comptime T: type) Schema {
    return openapi.schemaFromType(T);
}

/// Schema definition helpers for building OpenAPI schemas programmatically.
pub const SchemaBuilder = struct {
    pub fn string() Schema {
        return .{ .type = "string" };
    }

    pub fn stringWithFormat(format: []const u8) Schema {
        return .{ .type = "string", .format = format };
    }

    pub fn integer() Schema {
        return .{ .type = "integer" };
    }

    pub fn int32() Schema {
        return .{ .type = "integer", .format = "int32" };
    }

    pub fn int64() Schema {
        return .{ .type = "integer", .format = "int64" };
    }

    pub fn number() Schema {
        return .{ .type = "number" };
    }

    pub fn float() Schema {
        return .{ .type = "number", .format = "float" };
    }

    pub fn double() Schema {
        return .{ .type = "number", .format = "double" };
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

    pub fn nullable(comptime inner: Schema) Schema {
        var s = inner;
        s.nullable = true;
        return s;
    }

    pub fn withFormat(comptime schema: Schema, format: []const u8) Schema {
        var s = schema;
        s.format = format;
        return s;
    }

    pub fn email() Schema {
        return .{ .type = "string", .format = "email" };
    }

    pub fn uri() Schema {
        return .{ .type = "string", .format = "uri" };
    }

    pub fn uuid() Schema {
        return .{ .type = "string", .format = "uuid" };
    }

    pub fn date() Schema {
        return .{ .type = "string", .format = "date" };
    }

    pub fn dateTime() Schema {
        return .{ .type = "string", .format = "date-time" };
    }

    pub fn password() Schema {
        return .{ .type = "string", .format = "password" };
    }

    pub fn binary() Schema {
        return .{ .type = "string", .format = "binary" };
    }
};

/// Common content types for convenience.
pub const ContentTypes = struct {
    pub const JSON = http.Headers.ContentTypes.json;
    pub const HTML = http.Headers.ContentTypes.html;
    pub const TEXT = http.Headers.ContentTypes.plain;
    pub const XML = http.Headers.ContentTypes.xml;
    pub const FORM = http.Headers.ContentTypes.form;
    pub const MULTIPART = http.Headers.ContentTypes.multipart;
    pub const CSS = http.Headers.ContentTypes.css;
    pub const JS = http.Headers.ContentTypes.javascript;
    pub const PNG = http.Headers.ContentTypes.png;
    pub const JPEG = http.Headers.ContentTypes.jpeg;
    pub const GIF = http.Headers.ContentTypes.gif;
    pub const SVG = http.Headers.ContentTypes.svg;
    pub const ICO = http.Headers.ContentTypes.ico;
};

/// Common HTTP status code groups.
pub const StatusGroups = struct {
    pub fn isInformational(status: StatusCode) bool {
        const code = status.toInt();
        return code >= 100 and code < 200;
    }

    pub fn isSuccess(status: StatusCode) bool {
        return status.isSuccess();
    }

    pub fn isRedirect(status: StatusCode) bool {
        return status.isRedirect();
    }

    pub fn isClientError(status: StatusCode) bool {
        return status.isClientError();
    }

    pub fn isServerError(status: StatusCode) bool {
        return status.isServerError();
    }
};

/// Production-ready default configurations.
pub const Defaults = struct {
    pub const server = ServerConfig{
        .address = "127.0.0.1",
        .port = 8000,
        .max_body_size = 10 * 1024 * 1024,
        .num_threads = null,
        .enable_access_log = true,
        .auto_port = true,
        .max_port_attempts = 100,
        .read_buffer_size = 16384,
        .keepalive_timeout_ms = 5000,
        .max_connections = 10000,
        .tcp_nodelay = true,
        .reuse_port = true,
    };

    pub const cors = CorsConfig{
        .allowed_origins = &.{"*"},
        .allowed_methods = &.{ "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD" },
        .allowed_headers = &.{ "Content-Type", "Authorization", "X-Requested-With", "Accept", "Origin" },
        .max_age = 86400,
    };

    pub const rateLimit = RateLimitConfig{
        .requests_per_window = 100,
        .window_seconds = 60,
    };

    pub const security = SecurityHeadersConfig{
        .content_security_policy = "default-src 'self'",
        .x_content_type_options = true,
        .x_frame_options = .deny,
        .x_xss_protection = true,
        .referrer_policy = "strict-origin-when-cross-origin",
    };

    pub const graphql = GraphQLConfig{
        .enable_playground = true,
        .enable_introspection = true,
        .max_depth = 15,
        .max_complexity = 1000,
        .enable_batching = false,
        .enable_tracing = false,
        .enable_persisted_queries = false,
        .mask_errors = true,
        .enable_caching = false,
        .enable_cors = true,
        .enable_subscriptions = false,
        .ui_config = .{
            .provider = .graphiql,
            .theme = .dark,
            .title = "GraphQL Explorer",
            .show_docs = true,
            .show_history = true,
            .enable_persistence = true,
            .enable_shortcuts = true,
            .code_completion = true,
            .syntax_highlighting = true,
        },
        .complexity_config = .{
            .enabled = true,
            .max_complexity = 1000,
            .default_field_complexity = 1,
            .list_multiplier = 10,
        },
        .depth_config = .{
            .enabled = true,
            .max_depth = 15,
            .ignore_introspection = true,
        },
        .error_config = .{
            .mask_errors = true,
            .generic_message = "An unexpected error occurred",
            .include_stack_traces = false,
            .include_error_codes = true,
        },
    };

    pub const ws = WebSocketConfig{
        .max_message_size = 64 * 1024,
        .ping_interval_ms = 30000,
        .pong_timeout_ms = 10000,
    };

    pub const metrics_config = MetricsConfig{
        .prefix = "app_",
        .enable_process_metrics = true,
        .enable_runtime_metrics = true,
    };

    pub const cache_config = CacheConfig{
        .max_entries = 10000,
        .cleanup_interval_ms = 60000,
    };

    pub const session_config = SessionConfig{
        .ttl_ms = 24 * 60 * 60 * 1000,
        .secure = true,
        .http_only = true,
        .same_site = .lax,
    };
};

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
    _ = @import("graphql.zig");
    _ = @import("websocket.zig");
    _ = @import("metrics.zig");
    _ = @import("cache.zig");
    _ = @import("session.zig");
}
