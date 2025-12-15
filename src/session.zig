//! Session management for api.zig framework.
//! Provides secure session handling with multiple storage backends.
//!
//! ## Features
//! - Secure session ID generation
//! - In-memory and Redis-compatible storage
//! - Session expiration and cleanup
//! - Flash messages
//! - CSRF token integration

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;
const cache = @import("cache.zig");

/// Session ID length (32 bytes = 256 bits of entropy).
pub const SESSION_ID_LENGTH = 32;

/// Session data container.
pub const Session = struct {
    id: [SESSION_ID_LENGTH * 2]u8,
    data: std.StringHashMap([]const u8),
    flash_data: std.StringHashMap([]const u8),
    created_at: i64,
    last_accessed: i64,
    expires_at: i64,
    is_new: bool = false,
    is_modified: bool = false,

    pub fn init(allocator: std.mem.Allocator, id: [SESSION_ID_LENGTH * 2]u8, ttl_ms: u64) Session {
        const now = std.time.milliTimestamp();
        return .{
            .id = id,
            .data = std.StringHashMap([]const u8).init(allocator),
            .flash_data = std.StringHashMap([]const u8).init(allocator),
            .created_at = now,
            .last_accessed = now,
            .expires_at = now + @as(i64, @intCast(ttl_ms)),
        };
    }

    pub fn deinit(self: *Session) void {
        self.data.deinit();
        self.flash_data.deinit();
    }

    /// Gets a value from session.
    pub fn get(self: *Session, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    /// Sets a value in session.
    pub fn set(self: *Session, key: []const u8, value: []const u8) !void {
        try self.data.put(key, value);
        self.is_modified = true;
    }

    /// Removes a value from session.
    pub fn remove(self: *Session, key: []const u8) void {
        _ = self.data.remove(key);
        self.is_modified = true;
    }

    /// Checks if key exists.
    pub fn has(self: *Session, key: []const u8) bool {
        return self.data.contains(key);
    }

    /// Clears all session data.
    pub fn clear(self: *Session) void {
        self.data.clearRetainingCapacity();
        self.is_modified = true;
    }

    /// Sets a flash message (available for next request only).
    pub fn flash(self: *Session, key: []const u8, value: []const u8) !void {
        try self.flash_data.put(key, value);
        self.is_modified = true;
    }

    /// Gets and removes a flash message.
    pub fn getFlash(self: *Session, key: []const u8) ?[]const u8 {
        const value = self.flash_data.get(key);
        if (value != null) {
            _ = self.flash_data.remove(key);
            self.is_modified = true;
        }
        return value;
    }

    /// Checks if session is expired.
    pub fn isExpired(self: *const Session) bool {
        return std.time.milliTimestamp() > self.expires_at;
    }

    /// Extends session expiration.
    pub fn extend(self: *Session, ttl_ms: u64) void {
        self.expires_at = std.time.milliTimestamp() + @as(i64, @intCast(ttl_ms));
        self.is_modified = true;
    }

    /// Regenerates session ID (for security, e.g., after login).
    pub fn regenerate(self: *Session, new_id: [SESSION_ID_LENGTH * 2]u8) void {
        self.id = new_id;
        self.is_modified = true;
    }
};

/// Session store interface.
pub const Store = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        load: *const fn (*anyopaque, [SESSION_ID_LENGTH * 2]u8) ?Session,
        save: *const fn (*anyopaque, *Session) void,
        destroy: *const fn (*anyopaque, [SESSION_ID_LENGTH * 2]u8) void,
        cleanup: *const fn (*anyopaque) usize,
    };

    pub fn load(self: Store, id: [SESSION_ID_LENGTH * 2]u8) ?Session {
        return self.vtable.load(self.ptr, id);
    }

    pub fn save(self: Store, session: *Session) void {
        self.vtable.save(self.ptr, session);
    }

    pub fn destroy(self: Store, id: [SESSION_ID_LENGTH * 2]u8) void {
        self.vtable.destroy(self.ptr, id);
    }

    pub fn cleanup(self: Store) usize {
        return self.vtable.cleanup(self.ptr);
    }
};

/// In-memory session store.
pub const MemoryStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.HashMap([SESSION_ID_LENGTH * 2]u8, Session, SessionContext, std.hash_map.default_max_load_percentage),
    mutex: std.Thread.Mutex,
    config: SessionConfig,

    const SessionContext = struct {
        pub fn hash(_: @This(), key: [SESSION_ID_LENGTH * 2]u8) u64 {
            return std.hash.Wyhash.hash(0, &key);
        }

        pub fn eql(_: @This(), a: [SESSION_ID_LENGTH * 2]u8, b: [SESSION_ID_LENGTH * 2]u8) bool {
            return std.mem.eql(u8, &a, &b);
        }
    };

    pub fn init(allocator: std.mem.Allocator, config: SessionConfig) MemoryStore {
        return .{
            .allocator = allocator,
            .sessions = std.HashMap([SESSION_ID_LENGTH * 2]u8, Session, SessionContext, std.hash_map.default_max_load_percentage).init(allocator),
            .mutex = .{},
            .config = config,
        };
    }

    pub fn deinit(self: *MemoryStore) void {
        var iter = self.sessions.valueIterator();
        while (iter.next()) |session| {
            session.deinit();
        }
        self.sessions.deinit();
    }

    pub fn store(self: *MemoryStore) Store {
        return .{
            .ptr = self,
            .vtable = &.{
                .load = load,
                .save = save,
                .destroy = destroy,
                .cleanup = cleanup,
            },
        };
    }

    fn load(ptr: *anyopaque, id: [SESSION_ID_LENGTH * 2]u8) ?Session {
        const self: *MemoryStore = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        const session = self.sessions.getPtr(id) orelse return null;

        if (session.isExpired()) {
            session.deinit();
            _ = self.sessions.remove(id);
            return null;
        }

        session.last_accessed = std.time.milliTimestamp();
        return session.*;
    }

    fn save(ptr: *anyopaque, session: *Session) void {
        const self: *MemoryStore = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        self.sessions.put(session.id, session.*) catch {};
    }

    fn destroy(ptr: *anyopaque, id: [SESSION_ID_LENGTH * 2]u8) void {
        const self: *MemoryStore = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.sessions.getPtr(id)) |session| {
            session.deinit();
        }
        _ = self.sessions.remove(id);
    }

    fn cleanup(ptr: *anyopaque) usize {
        const self: *MemoryStore = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        var removed: usize = 0;
        const now = std.time.milliTimestamp();

        var ids_to_remove: std.ArrayListUnmanaged([SESSION_ID_LENGTH * 2]u8) = .{};
        defer ids_to_remove.deinit(self.allocator);

        var iter = self.sessions.iterator();
        while (iter.next()) |entry| {
            if (now > entry.value_ptr.expires_at) {
                ids_to_remove.append(self.allocator, entry.key_ptr.*) catch {};
            }
        }

        for (ids_to_remove.items) |id| {
            if (self.sessions.getPtr(id)) |session| {
                session.deinit();
            }
            _ = self.sessions.remove(id);
            removed += 1;
        }

        return removed;
    }
};

/// Session configuration.
pub const SessionConfig = struct {
    /// Session cookie name.
    cookie_name: []const u8 = "session_id",
    /// Session TTL in milliseconds.
    ttl_ms: u64 = 24 * 60 * 60 * 1000, // 24 hours
    /// Cookie path.
    path: []const u8 = "/",
    /// Cookie domain (null = current domain).
    domain: ?[]const u8 = null,
    /// Secure flag (HTTPS only).
    secure: bool = true,
    /// HttpOnly flag.
    http_only: bool = true,
    /// SameSite attribute.
    same_site: SameSite = .lax,
    /// Rolling sessions (extend on each request).
    rolling: bool = true,
    /// Regenerate ID after login.
    regenerate_on_login: bool = true,
    /// Maximum sessions per user.
    max_sessions_per_user: ?u32 = null,
};

/// SameSite cookie attribute.
pub const SameSite = enum {
    strict,
    lax,
    none,

    pub fn toString(self: SameSite) []const u8 {
        return switch (self) {
            .strict => "Strict",
            .lax => "Lax",
            .none => "None",
        };
    }
};

/// Session manager.
pub const Manager = struct {
    allocator: std.mem.Allocator,
    store: Store,
    config: SessionConfig,

    pub fn init(allocator: std.mem.Allocator, store: Store, config: SessionConfig) Manager {
        return .{
            .allocator = allocator,
            .store = store,
            .config = config,
        };
    }

    /// Gets or creates a session for the request.
    pub fn getSession(self: *Manager, ctx: *Context) !*Session {
        // Try to get existing session from cookie
        const session_id = self.getSessionIdFromCookie(ctx);

        if (session_id) |id| {
            if (self.store.load(id)) |session| {
                const sess = try self.allocator.create(Session);
                sess.* = session;

                // Rolling session - extend expiration
                if (self.config.rolling) {
                    sess.extend(self.config.ttl_ms);
                }

                return sess;
            }
        }

        // Create new session
        return self.createSession();
    }

    /// Creates a new session.
    pub fn createSession(self: *Manager) !*Session {
        const id = generateSessionId();
        const session = try self.allocator.create(Session);
        session.* = Session.init(self.allocator, id, self.config.ttl_ms);
        session.is_new = true;
        return session;
    }

    /// Saves a session.
    pub fn saveSession(self: *Manager, session: *Session, response: *Response) void {
        self.store.save(session);

        // Set session cookie
        if (session.is_new or session.is_modified) {
            self.setSessionCookie(response, &session.id);
        }
    }

    /// Destroys a session.
    pub fn destroySession(self: *Manager, session: *Session, response: *Response) void {
        self.store.destroy(session.id);
        self.clearSessionCookie(response);
    }

    /// Regenerates session ID.
    pub fn regenerateId(self: *Manager, session: *Session) void {
        const old_id = session.id;
        const new_id = generateSessionId();
        session.regenerate(new_id);
        self.store.destroy(old_id);
    }

    fn getSessionIdFromCookie(self: *Manager, ctx: *Context) ?[SESSION_ID_LENGTH * 2]u8 {
        const cookie_header = ctx.header("Cookie") orelse return null;

        // Parse cookies
        var iter = std.mem.splitSequence(u8, cookie_header, "; ");
        while (iter.next()) |part| {
            var kv = std.mem.splitScalar(u8, part, '=');
            const name = kv.next() orelse continue;
            const value = kv.next() orelse continue;

            if (std.mem.eql(u8, name, self.config.cookie_name)) {
                if (value.len == SESSION_ID_LENGTH * 2) {
                    var id: [SESSION_ID_LENGTH * 2]u8 = undefined;
                    @memcpy(&id, value);
                    return id;
                }
            }
        }

        return null;
    }

    fn setSessionCookie(self: *Manager, response: *Response, id: []const u8) void {
        var buf: [512]u8 = undefined;
        var pos: usize = 0;

        // Name=Value
        const name_value = std.fmt.bufPrint(buf[pos..], "{s}={s}", .{ self.config.cookie_name, id }) catch return;
        pos += name_value.len;

        // Path
        const path = std.fmt.bufPrint(buf[pos..], "; Path={s}", .{self.config.path}) catch return;
        pos += path.len;

        // Domain
        if (self.config.domain) |domain| {
            const domain_str = std.fmt.bufPrint(buf[pos..], "; Domain={s}", .{domain}) catch return;
            pos += domain_str.len;
        }

        // Max-Age
        const max_age = std.fmt.bufPrint(buf[pos..], "; Max-Age={d}", .{self.config.ttl_ms / 1000}) catch return;
        pos += max_age.len;

        // SameSite
        const same_site = std.fmt.bufPrint(buf[pos..], "; SameSite={s}", .{self.config.same_site.toString()}) catch return;
        pos += same_site.len;

        // Secure
        if (self.config.secure) {
            const secure = std.fmt.bufPrint(buf[pos..], "; Secure", .{}) catch return;
            pos += secure.len;
        }

        // HttpOnly
        if (self.config.http_only) {
            const http_only = std.fmt.bufPrint(buf[pos..], "; HttpOnly", .{}) catch return;
            pos += http_only.len;
        }

        response.setHeader("Set-Cookie", buf[0..pos]);
    }

    fn clearSessionCookie(self: *Manager, response: *Response) void {
        var buf: [256]u8 = undefined;
        const cookie = std.fmt.bufPrint(&buf, "{s}=; Path={s}; Max-Age=0; HttpOnly", .{ self.config.cookie_name, self.config.path }) catch return;
        response.setHeader("Set-Cookie", cookie);
    }
};

/// Converts a byte slice to hexadecimal string.
fn bytesToHex(bytes: []const u8, out: []u8) void {
    const hex_chars = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        out[i * 2] = hex_chars[byte >> 4];
        out[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
}

/// Generates a cryptographically secure session ID.
pub fn generateSessionId() [SESSION_ID_LENGTH * 2]u8 {
    var random_bytes: [SESSION_ID_LENGTH]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);

    var hex_id: [SESSION_ID_LENGTH * 2]u8 = undefined;
    bytesToHex(&random_bytes, &hex_id);

    return hex_id;
}

/// CSRF token management.
pub const CSRF = struct {
    pub const TOKEN_LENGTH = 32;

    /// Generates a CSRF token and stores it in session.
    pub fn generate(session: *Session) ![TOKEN_LENGTH * 2]u8 {
        var random_bytes: [TOKEN_LENGTH]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        var token: [TOKEN_LENGTH * 2]u8 = undefined;
        bytesToHex(&random_bytes, &token);

        try session.set("_csrf_token", &token);
        return token;
    }

    /// Validates a CSRF token.
    pub fn validate(session: *Session, token: []const u8) bool {
        const stored_token = session.get("_csrf_token") orelse return false;
        return std.mem.eql(u8, stored_token, token);
    }

    /// Gets the current CSRF token.
    pub fn getToken(session: *Session) ?[]const u8 {
        return session.get("_csrf_token");
    }
};

/// Session middleware for automatic session handling.
pub fn sessionMiddleware(manager: *Manager) type {
    return struct {
        pub fn handle(ctx: *Context, next: *const fn (*Context) Response) Response {
            // Get or create session
            const session = manager.getSession(ctx) catch {
                return next(ctx);
            };

            // Store session in context state
            ctx.set("session", @ptrCast(session)) catch {};

            // Call next handler
            var response = next(ctx);

            // Save session
            manager.saveSession(session, &response);

            return response;
        }
    };
}

/// Default session configurations.
pub const Defaults = struct {
    pub const standard: SessionConfig = .{};

    pub const secure: SessionConfig = .{
        .secure = true,
        .http_only = true,
        .same_site = .strict,
        .ttl_ms = 2 * 60 * 60 * 1000, // 2 hours
    };

    pub const persistent: SessionConfig = .{
        .ttl_ms = 30 * 24 * 60 * 60 * 1000, // 30 days
        .rolling = true,
    };

    pub const api: SessionConfig = .{
        .ttl_ms = 15 * 60 * 1000, // 15 minutes
        .rolling = false,
    };
};

test "session basic operations" {
    const allocator = std.testing.allocator;
    var id: [SESSION_ID_LENGTH * 2]u8 = undefined;
    @memset(&id, 'a');

    var session = Session.init(allocator, id, 3600000);
    defer session.deinit();

    try session.set("user_id", "12345");
    try std.testing.expectEqualStrings("12345", session.get("user_id").?);

    try session.flash("message", "Welcome!");
    try std.testing.expectEqualStrings("Welcome!", session.getFlash("message").?);
    try std.testing.expect(session.getFlash("message") == null); // Flash is consumed
}

test "session id generation" {
    const id1 = generateSessionId();
    const id2 = generateSessionId();

    // Should be unique
    try std.testing.expect(!std.mem.eql(u8, &id1, &id2));

    // Should be correct length
    try std.testing.expectEqual(SESSION_ID_LENGTH * 2, id1.len);
}

test "memory store operations" {
    const allocator = std.testing.allocator;
    var memory_store = MemoryStore.init(allocator, .{});
    defer memory_store.deinit();

    const store = memory_store.store();

    // Create and save session
    var id: [SESSION_ID_LENGTH * 2]u8 = undefined;
    @memset(&id, 'b');

    var session = Session.init(allocator, id, 3600000);
    try session.set("key", "value");

    store.save(&session);

    // Load session
    const loaded = store.load(id);
    try std.testing.expect(loaded != null);
}
