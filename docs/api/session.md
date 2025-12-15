# Session Module

The Session module provides secure session management with support for multiple storage backends, CSRF protection, and secure cookie handling.

## Overview

```zig
const session = @import("api").session;
```

## Quick Start

```zig
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable sessions
    try app.enableSessions(.{
        .secret = "your-secret-key-at-least-32-characters",
        .cookie_name = "session_id",
        .max_age_seconds = 86400, // 24 hours
    });

    app.router.get("/profile", profileHandler);
    app.router.post("/login", loginHandler);

    try app.listen(.{ .port = 8080 });
}
```

## Session Configuration

### SessionConfig

```zig
const SessionConfig = struct {
    // Secret key for signing session IDs (min 32 chars)
    secret: []const u8,
    
    // Cookie name for session ID
    cookie_name: []const u8 = "session_id",
    
    // Session lifetime in seconds
    max_age_seconds: u32 = 86400,
    
    // Cookie path
    path: []const u8 = "/",
    
    // Cookie domain (null = current domain)
    domain: ?[]const u8 = null,
    
    // Secure flag (HTTPS only)
    secure: bool = true,
    
    // HttpOnly flag (no JavaScript access)
    http_only: bool = true,
    
    // SameSite attribute
    same_site: SameSite = .lax,
    
    // Session ID length in bytes
    id_length: u8 = 32,
    
    // Cleanup interval for expired sessions
    cleanup_interval_seconds: u32 = 3600,
};

const SameSite = enum {
    strict, // Most restrictive
    lax,    // Default, good balance
    none,   // Required for cross-site
};
```

## Session Management

### Session Structure

```zig
const Session = struct {
    id: []const u8,
    data: std.StringHashMap([]const u8),
    created_at: i64,
    last_accessed: i64,
    expires_at: i64,
    is_new: bool,
    modified: bool,

    /// Gets a session value.
    pub fn get(self: *Session, key: []const u8) ?[]const u8;

    /// Sets a session value.
    pub fn set(self: *Session, key: []const u8, value: []const u8) !void;

    /// Removes a session value.
    pub fn remove(self: *Session, key: []const u8) void;

    /// Checks if session has a key.
    pub fn has(self: *Session, key: []const u8) bool;

    /// Clears all session data.
    pub fn clear(self: *Session) void;

    /// Invalidates the session (logout).
    pub fn invalidate(self: *Session) void;

    /// Regenerates session ID (security).
    pub fn regenerate(self: *Session) !void;

    /// Gets flash message (auto-deleted after read).
    pub fn getFlash(self: *Session, key: []const u8) ?[]const u8;

    /// Sets flash message.
    pub fn setFlash(self: *Session, key: []const u8, value: []const u8) !void;
};
```

### Working with Sessions

```zig
fn profileHandler(ctx: *api.Context) !void {
    // Get or create session
    const sess = try ctx.session() orelse {
        ctx.response.setStatus(.unauthorized);
        return;
    };

    // Get user ID from session
    const user_id = sess.get("user_id") orelse {
        return ctx.response.redirect("/login");
    };

    // Get user data
    const user = try db.getUserById(user_id);
    try ctx.response.json(user);
}

fn loginHandler(ctx: *api.Context) !void {
    const body = try ctx.request.json(LoginRequest);
    
    // Validate credentials
    const user = try auth.authenticate(body.username, body.password);
    
    // Get session
    var sess = try ctx.session();
    
    // Regenerate session ID after login (security)
    try sess.regenerate();
    
    // Store user data
    try sess.set("user_id", user.id);
    try sess.set("username", user.username);
    try sess.set("role", user.role);
    
    // Set flash message
    try sess.setFlash("message", "Welcome back!");
    
    try ctx.response.json(.{ .success = true });
}

fn logoutHandler(ctx: *api.Context) !void {
    if (try ctx.session()) |sess| {
        sess.invalidate();
    }
    ctx.response.redirect("/");
}
```

## Session Storage

### Memory Store (Default)

```zig
const MemoryStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),
    mutex: std.Thread.Mutex,
    config: SessionConfig,

    pub fn init(allocator: std.mem.Allocator, config: SessionConfig) MemoryStore;
    pub fn deinit(self: *MemoryStore) void;
    
    /// Gets session by ID.
    pub fn get(self: *MemoryStore, id: []const u8) ?*Session;
    
    /// Creates a new session.
    pub fn create(self: *MemoryStore) !*Session;
    
    /// Saves session changes.
    pub fn save(self: *MemoryStore, sess: *Session) !void;
    
    /// Destroys a session.
    pub fn destroy(self: *MemoryStore, id: []const u8) void;
    
    /// Removes expired sessions.
    pub fn cleanup(self: *MemoryStore) void;
};
```

### Using Memory Store

```zig
var store = session.MemoryStore.init(allocator, .{
    .secret = "your-secret-key",
    .max_age_seconds = 86400,
});
defer store.deinit();

// Create session
var sess = try store.create();

// Set data
try sess.set("key", "value");

// Save changes
try store.save(sess);

// Retrieve session
if (store.get(sess.id)) |s| {
    const value = s.get("key");
}

// Cleanup expired
store.cleanup();
```

## Session Manager

### Manager Structure

```zig
const Manager = struct {
    allocator: std.mem.Allocator,
    store: *MemoryStore,
    config: SessionConfig,

    /// Gets existing session or creates new one.
    pub fn getOrCreate(self: *Manager, ctx: *Context) !*Session;
    
    /// Gets existing session only.
    pub fn get(self: *Manager, ctx: *Context) ?*Session;
    
    /// Saves session and sets cookie.
    pub fn save(self: *Manager, sess: *Session, response: *Response) !void;
    
    /// Destroys session.
    pub fn destroy(self: *Manager, sess: *Session, response: *Response) void;
    
    /// Starts background cleanup task.
    pub fn startCleanupTask(self: *Manager) !void;
};
```

### Using Session Manager

```zig
fn middleware(ctx: *api.Context, next: api.NextFn) !void {
    const manager = ctx.app.session_manager orelse return next(ctx);
    
    // Load session
    var sess = try manager.getOrCreate(ctx);
    
    // Call handler
    try next(ctx);
    
    // Save session if modified
    if (sess.modified) {
        try manager.save(sess, ctx.response);
    }
}
```

## CSRF Protection

### CSRF Module

```zig
const CSRF = struct {
    pub const TOKEN_LENGTH = 32;

    /// Generates a CSRF token and stores it in session.
    pub fn generate(sess: *Session) ![TOKEN_LENGTH * 2]u8;

    /// Validates a CSRF token from request.
    pub fn validate(sess: *Session, token: []const u8) bool;

    /// Middleware for CSRF protection.
    pub fn middleware(ctx: *api.Context, next: api.NextFn) !void {
        // Skip safe methods
        if (isSafeMethod(ctx.request.method)) {
            return next(ctx);
        }

        // Get session
        const sess = try ctx.session() orelse return error.NoSession;

        // Get token from request
        const token = ctx.request.getHeader("X-CSRF-Token") orelse
            ctx.request.formValue("_csrf") orelse
            return error.MissingCSRFToken;

        // Validate
        if (!validate(sess, token)) {
            ctx.response.setStatus(.forbidden);
            try ctx.response.send("Invalid CSRF token");
            return;
        }

        try next(ctx);
    }
};
```

### Using CSRF Protection

```zig
fn formHandler(ctx: *api.Context) !void {
    const sess = try ctx.session();
    
    // Generate CSRF token
    const token = try session.CSRF.generate(sess);
    
    // Include in form
    const html = try std.fmt.allocPrint(ctx.allocator,
        \\<form method="POST" action="/submit">
        \\  <input type="hidden" name="_csrf" value="{s}">
        \\  <input type="text" name="data">
        \\  <button type="submit">Submit</button>
        \\</form>
    , .{token});
    
    ctx.response.setHeader("Content-Type", "text/html");
    try ctx.response.send(html);
}

fn submitHandler(ctx: *api.Context) !void {
    // CSRF validation happens in middleware
    const body = try ctx.request.formData();
    // Process form...
}

// Enable CSRF middleware
app.use(session.CSRF.middleware);
```

## Secure Cookie Handling

### Setting Session Cookie

```zig
fn setCookie(self: *Manager, sess: *Session, response: *Response) void {
    var cookie = std.ArrayList(u8).init(self.allocator);
    defer cookie.deinit();

    // Cookie name and value
    try cookie.writer().print("{s}={s}", .{self.config.cookie_name, sess.id});

    // Path
    try cookie.writer().print("; Path={s}", .{self.config.path});

    // Domain
    if (self.config.domain) |domain| {
        try cookie.writer().print("; Domain={s}", .{domain});
    }

    // Max-Age
    try cookie.writer().print("; Max-Age={d}", .{self.config.max_age_seconds});

    // Secure
    if (self.config.secure) {
        try cookie.writer().writeAll("; Secure");
    }

    // HttpOnly
    if (self.config.http_only) {
        try cookie.writer().writeAll("; HttpOnly");
    }

    // SameSite
    switch (self.config.same_site) {
        .strict => try cookie.writer().writeAll("; SameSite=Strict"),
        .lax => try cookie.writer().writeAll("; SameSite=Lax"),
        .none => try cookie.writer().writeAll("; SameSite=None"),
    }

    response.setHeader("Set-Cookie", cookie.items);
}
```

### Cookie Security Best Practices

```zig
const secure_config = session.SessionConfig{
    .secret = std.crypto.random.bytes(32), // Strong random secret
    .secure = true,                         // HTTPS only
    .http_only = true,                      // No JS access
    .same_site = .strict,                   // CSRF protection
    .max_age_seconds = 3600,                // 1 hour
};
```

## Flash Messages

Flash messages are one-time messages that are automatically deleted after being read.

```zig
fn loginHandler(ctx: *api.Context) !void {
    var sess = try ctx.session();
    
    if (auth.login(ctx)) {
        try sess.setFlash("success", "Login successful!");
        return ctx.response.redirect("/dashboard");
    } else {
        try sess.setFlash("error", "Invalid credentials");
        return ctx.response.redirect("/login");
    }
}

fn dashboardHandler(ctx: *api.Context) !void {
    var sess = try ctx.session();
    
    // Get and auto-delete flash message
    const success_msg = sess.getFlash("success");
    const error_msg = sess.getFlash("error");
    
    // Render page with messages
    try ctx.response.render("dashboard", .{
        .success = success_msg,
        .error = error_msg,
    });
}
```

## Session ID Generation

```zig
/// Generates a cryptographically secure session ID.
pub fn generateSessionId() [SESSION_ID_LENGTH * 2]u8 {
    var random_bytes: [SESSION_ID_LENGTH]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);

    var hex_id: [SESSION_ID_LENGTH * 2]u8 = undefined;
    bytesToHex(&random_bytes, &hex_id);

    return hex_id;
}
```

## App Integration

### Enabling Sessions

```zig
var app = try api.App.init(allocator, .{});

try app.enableSessions(.{
    .secret = "your-very-long-secret-key-for-signing",
    .cookie_name = "app_session",
    .max_age_seconds = 86400,
    .secure = true,
    .http_only = true,
    .same_site = .lax,
});

// Access session manager
if (app.session_manager) |manager| {
    // Use manager
}
```

## Example: Complete Auth System

```zig
const std = @import("std");
const api = @import("api");
const session = api.session;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable sessions with secure settings
    try app.enableSessions(.{
        .secret = "production-secret-key-minimum-32-chars!",
        .cookie_name = "sid",
        .max_age_seconds = 7200, // 2 hours
        .secure = true,
        .http_only = true,
        .same_site = .strict,
    });

    // CSRF protection for mutations
    app.use(csrfMiddleware);

    // Auth routes
    app.router.get("/login", loginPageHandler);
    app.router.post("/login", loginHandler);
    app.router.post("/logout", logoutHandler);
    
    // Protected routes
    app.router.get("/dashboard", requireAuth(dashboardHandler));
    app.router.get("/profile", requireAuth(profileHandler));
    app.router.post("/profile", requireAuth(updateProfileHandler));

    try app.listen(.{ .port = 8080 });
}

fn csrfMiddleware(ctx: *api.Context, next: api.NextFn) !void {
    // Skip GET, HEAD, OPTIONS
    if (ctx.request.method == .GET or 
        ctx.request.method == .HEAD or
        ctx.request.method == .OPTIONS) {
        return next(ctx);
    }

    var sess = try ctx.session() orelse return error.NoSession;
    
    const token = ctx.request.getHeader("X-CSRF-Token") orelse
        ctx.request.formValue("_csrf") orelse {
        ctx.response.setStatus(.forbidden);
        return;
    };

    if (!session.CSRF.validate(sess, token)) {
        ctx.response.setStatus(.forbidden);
        try ctx.response.json(.{ .error = "Invalid CSRF token" });
        return;
    }

    try next(ctx);
}

fn requireAuth(comptime handler: api.HandlerFn) api.HandlerFn {
    return struct {
        fn handle(ctx: *api.Context) !void {
            const sess = try ctx.session() orelse {
                return ctx.response.redirect("/login");
            };

            if (sess.get("user_id") == null) {
                try sess.setFlash("error", "Please login to continue");
                return ctx.response.redirect("/login");
            }

            // Check session expiration
            if (std.time.timestamp() > sess.expires_at) {
                sess.invalidate();
                try sess.setFlash("error", "Session expired");
                return ctx.response.redirect("/login");
            }

            // Update last accessed
            sess.last_accessed = std.time.timestamp();

            try handler(ctx);
        }
    }.handle;
}

fn loginPageHandler(ctx: *api.Context) !void {
    var sess = try ctx.session();
    const csrf_token = try session.CSRF.generate(sess);
    const error_msg = sess.getFlash("error");

    const html = try std.fmt.allocPrint(ctx.allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<body>
        \\  {s}
        \\  <form method="POST" action="/login">
        \\    <input type="hidden" name="_csrf" value="{s}">
        \\    <input type="text" name="username" placeholder="Username">
        \\    <input type="password" name="password" placeholder="Password">
        \\    <button type="submit">Login</button>
        \\  </form>
        \\</body>
        \\</html>
    , .{
        if (error_msg) |msg| std.fmt.allocPrint(ctx.allocator, "<p style='color:red'>{s}</p>", .{msg}) catch "" else "",
        &csrf_token,
    });

    ctx.response.setHeader("Content-Type", "text/html");
    try ctx.response.send(html);
}

fn loginHandler(ctx: *api.Context) !void {
    const form = try ctx.request.formData();
    const username = form.get("username") orelse "";
    const password = form.get("password") orelse "";

    // Authenticate
    const user = auth.authenticate(username, password) catch |err| {
        var sess = try ctx.session();
        try sess.setFlash("error", "Invalid credentials");
        return ctx.response.redirect("/login");
    };

    var sess = try ctx.session();
    
    // Regenerate session ID after successful login
    try sess.regenerate();
    
    // Store user info
    try sess.set("user_id", user.id);
    try sess.set("username", user.username);
    try sess.set("role", user.role);
    try sess.set("login_time", std.fmt.allocPrint(ctx.allocator, "{d}", .{std.time.timestamp()}) catch "");

    try sess.setFlash("success", "Welcome back!");
    ctx.response.redirect("/dashboard");
}

fn logoutHandler(ctx: *api.Context) !void {
    if (try ctx.session()) |sess| {
        sess.invalidate();
    }
    ctx.response.redirect("/login");
}

fn dashboardHandler(ctx: *api.Context) !void {
    var sess = (try ctx.session()).?;
    const username = sess.get("username") orelse "User";
    const success = sess.getFlash("success");

    try ctx.response.json(.{
        .message = if (success) |msg| msg else "Dashboard",
        .user = username,
    });
}
```

## Session Security Checklist

- [ ] Use strong, random secret key (32+ characters)
- [ ] Enable `secure` flag in production (HTTPS only)
- [ ] Enable `http_only` flag (prevent XSS)
- [ ] Set appropriate `same_site` attribute
- [ ] Regenerate session ID after login
- [ ] Implement session timeout
- [ ] Use CSRF protection for mutations
- [ ] Store minimal data in session
- [ ] Implement proper logout (invalidate session)
- [ ] Regular cleanup of expired sessions

## See Also

- [Context Module](context.md) - For request context
- [Middleware Module](middleware.md) - For authentication middleware
- [Response Module](response.md) - For cookie handling
