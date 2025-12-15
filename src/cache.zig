//! Caching support for api.zig framework.
//! Provides in-memory caching, TTL expiration, and cache middleware.
//!
//! ## Features
//! - LRU (Least Recently Used) cache eviction
//! - TTL (Time To Live) expiration
//! - Thread-safe operations
//! - Cache statistics
//! - HTTP response caching middleware
//! - Cache invalidation patterns

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;

/// Cache entry with metadata.
pub fn Entry(comptime V: type) type {
    return struct {
        value: V,
        created_at: i64,
        expires_at: ?i64,
        access_count: u64,
        last_accessed: i64,
        size_bytes: usize,
    };
}

/// Thread-safe LRU cache implementation.
pub fn Cache(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const EntryType = Entry(V);

        allocator: std.mem.Allocator,
        data: std.HashMap(K, EntryType, std.hash_map.AutoContext(K), std.hash_map.default_max_load_percentage),
        access_order: std.ArrayListUnmanaged(K),
        mutex: std.Thread.Mutex,
        config: CacheConfig,
        stats: CacheStats,

        pub fn init(allocator: std.mem.Allocator, config: CacheConfig) Self {
            return .{
                .allocator = allocator,
                .data = std.HashMap(K, EntryType, std.hash_map.AutoContext(K), std.hash_map.default_max_load_percentage).init(allocator),
                .access_order = .{},
                .mutex = .{},
                .config = config,
                .stats = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
            self.access_order.deinit(self.allocator);
        }

        /// Gets a value from cache.
        pub fn get(self: *Self, key: K) ?V {
            self.mutex.lock();
            defer self.mutex.unlock();

            const entry = self.data.getPtr(key) orelse {
                self.stats.misses += 1;
                return null;
            };

            // Check expiration
            if (entry.expires_at) |expires| {
                if (std.time.milliTimestamp() > expires) {
                    _ = self.data.remove(key);
                    self.stats.misses += 1;
                    self.stats.expirations += 1;
                    return null;
                }
            }

            // Update access stats
            entry.access_count += 1;
            entry.last_accessed = std.time.milliTimestamp();
            self.stats.hits += 1;

            // Move to end of access order (most recently used)
            self.updateAccessOrder(key);

            return entry.value;
        }

        /// Sets a value in cache with optional TTL.
        pub fn set(self: *Self, key: K, value: V, ttl_ms: ?u64) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            // Check if we need to evict
            while (self.data.count() >= self.config.max_entries) {
                self.evictLRU();
            }

            const now = std.time.milliTimestamp();
            const entry = EntryType{
                .value = value,
                .created_at = now,
                .expires_at = if (ttl_ms) |ttl| now + @as(i64, @intCast(ttl)) else null,
                .access_count = 0,
                .last_accessed = now,
                .size_bytes = @sizeOf(V),
            };

            try self.data.put(key, entry);
            try self.access_order.append(self.allocator, key);
            self.stats.sets += 1;
        }

        /// Removes a value from cache.
        pub fn remove(self: *Self, key: K) bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.data.remove(key)) {
                self.removeFromAccessOrder(key);
                self.stats.deletions += 1;
                return true;
            }
            return false;
        }

        /// Checks if key exists (without updating access time).
        pub fn has(self: *Self, key: K) bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            const entry = self.data.get(key) orelse return false;

            // Check expiration
            if (entry.expires_at) |expires| {
                if (std.time.milliTimestamp() > expires) {
                    return false;
                }
            }

            return true;
        }

        /// Clears all entries.
        pub fn clear(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.data.clearRetainingCapacity();
            self.access_order.clearRetainingCapacity();
            self.stats.clears += 1;
        }

        /// Returns current entry count.
        pub fn count(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.data.count();
        }

        /// Gets cache statistics.
        pub fn getStats(self: *Self) CacheStats {
            self.mutex.lock();
            defer self.mutex.unlock();
            var stats = self.stats;
            stats.entries = self.data.count();
            return stats;
        }

        /// Removes expired entries.
        pub fn cleanup(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();

            var removed: usize = 0;
            const now = std.time.milliTimestamp();

            var keys_to_remove = std.ArrayList(K).init(self.allocator);
            defer keys_to_remove.deinit();

            var iter = self.data.iterator();
            while (iter.next()) |entry| {
                if (entry.value_ptr.expires_at) |expires| {
                    if (now > expires) {
                        keys_to_remove.append(entry.key_ptr.*) catch {};
                    }
                }
            }

            for (keys_to_remove.items) |key| {
                _ = self.data.remove(key);
                self.removeFromAccessOrder(key);
                removed += 1;
            }

            self.stats.expirations += removed;
            return removed;
        }

        fn evictLRU(self: *Self) void {
            if (self.access_order.items.len == 0) return;

            const key = self.access_order.orderedRemove(0);
            _ = self.data.remove(key);
            self.stats.evictions += 1;
        }

        fn updateAccessOrder(self: *Self, key: K) void {
            self.removeFromAccessOrder(key);
            self.access_order.append(self.allocator, key) catch {};
        }

        fn removeFromAccessOrder(self: *Self, key: K) void {
            var i: usize = 0;
            while (i < self.access_order.items.len) {
                if (std.meta.eql(self.access_order.items[i], key)) {
                    _ = self.access_order.orderedRemove(i);
                    return;
                }
                i += 1;
            }
        }
    };
}

/// Cache configuration.
pub const CacheConfig = struct {
    max_entries: usize = 10000,
    default_ttl_ms: ?u64 = null,
    cleanup_interval_ms: u64 = 60000,
    enable_stats: bool = true,
};

/// Cache statistics.
pub const CacheStats = struct {
    hits: u64 = 0,
    misses: u64 = 0,
    sets: u64 = 0,
    deletions: u64 = 0,
    evictions: u64 = 0,
    expirations: u64 = 0,
    clears: u64 = 0,
    entries: usize = 0,

    pub fn hitRate(self: *const CacheStats) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

/// String key cache (most common use case).
pub const StringCache = Cache([]const u8, []const u8);

/// Response cache for HTTP caching.
pub const ResponseCache = struct {
    cache: Cache(u64, CachedResponse),
    config: ResponseCacheConfig,

    pub const CachedResponse = struct {
        status: u16,
        body: []const u8,
        content_type: []const u8,
        headers: []const HeaderPair,
        cached_at: i64,
    };

    pub const HeaderPair = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const ResponseCacheConfig = struct {
        max_entries: usize = 1000,
        default_ttl_ms: u64 = 300000, // 5 minutes
        max_body_size: usize = 1024 * 1024, // 1MB
        vary_by_headers: []const []const u8 = &.{"Accept"},
        cacheable_methods: []const []const u8 = &.{"GET"},
        cacheable_statuses: []const u16 = &.{ 200, 301, 404 },
    };

    pub fn init(allocator: std.mem.Allocator, config: ResponseCacheConfig) ResponseCache {
        return .{
            .cache = Cache(u64, CachedResponse).init(allocator, .{
                .max_entries = config.max_entries,
                .default_ttl_ms = config.default_ttl_ms,
            }),
            .config = config,
        };
    }

    pub fn deinit(self: *ResponseCache) void {
        self.cache.deinit();
    }

    /// Generates cache key from context.
    pub fn keyFor(self: *ResponseCache, ctx: *Context) u64 {
        var hasher = std.hash.Wyhash.init(0);

        // Hash method + path
        hasher.update(ctx.request.method.toString());
        hasher.update(ctx.request.uri);

        // Hash vary headers
        for (self.config.vary_by_headers) |header_name| {
            if (ctx.header(header_name)) |value| {
                hasher.update(header_name);
                hasher.update(value);
            }
        }

        return hasher.final();
    }

    /// Gets cached response if available.
    pub fn get(self: *ResponseCache, ctx: *Context) ?Response {
        const key = self.keyFor(ctx);
        const cached = self.cache.get(key) orelse return null;

        var response = Response.init();
        response.status = @enumFromInt(cached.status);
        response.body = cached.body;
        response.content_type = cached.content_type;
        response.setHeader("X-Cache", "HIT");
        response.setHeader("X-Cache-Age", std.fmt.allocPrint(ctx.allocator, "{d}", .{std.time.milliTimestamp() - cached.cached_at}) catch "0");

        return response;
    }

    /// Caches a response.
    pub fn set(self: *ResponseCache, ctx: *Context, response: Response) !void {
        // Check if cacheable
        if (!self.isCacheable(ctx, response)) return;

        const key = self.keyFor(ctx);

        const cached = CachedResponse{
            .status = @intFromEnum(response.status),
            .body = response.body orelse "",
            .content_type = response.content_type orelse "text/plain",
            .headers = &.{},
            .cached_at = std.time.milliTimestamp(),
        };

        try self.cache.set(key, cached, self.config.default_ttl_ms);
    }

    fn isCacheable(self: *ResponseCache, ctx: *Context, response: Response) bool {
        // Check method
        var method_ok = false;
        for (self.config.cacheable_methods) |m| {
            if (std.mem.eql(u8, ctx.request.method.toString(), m)) {
                method_ok = true;
                break;
            }
        }
        if (!method_ok) return false;

        // Check status
        var status_ok = false;
        for (self.config.cacheable_statuses) |s| {
            if (@intFromEnum(response.status) == s) {
                status_ok = true;
                break;
            }
        }
        if (!status_ok) return false;

        // Check body size
        if (response.body) |body| {
            if (body.len > self.config.max_body_size) return false;
        }

        // Check Cache-Control headers
        if (ctx.header("Cache-Control")) |cc| {
            if (std.mem.indexOf(u8, cc, "no-store") != null) return false;
            if (std.mem.indexOf(u8, cc, "private") != null) return false;
        }

        return true;
    }
};

/// Cache middleware for automatic response caching.
pub fn cacheMiddleware(cache: *ResponseCache) type {
    return struct {
        pub fn handle(ctx: *Context, next: *const fn (*Context) Response) Response {
            // Try cache first
            if (cache.get(ctx)) |cached_response| {
                return cached_response;
            }

            // Get fresh response
            var response = next(ctx);
            response.setHeader("X-Cache", "MISS");

            // Cache response
            cache.set(ctx, response) catch {};

            return response;
        }
    };
}

/// Cache control header builder.
pub const CacheControl = struct {
    max_age: ?u32 = null,
    s_maxage: ?u32 = null,
    no_cache: bool = false,
    no_store: bool = false,
    no_transform: bool = false,
    must_revalidate: bool = false,
    proxy_revalidate: bool = false,
    private: bool = false,
    public: bool = false,
    immutable: bool = false,
    stale_while_revalidate: ?u32 = null,
    stale_if_error: ?u32 = null,

    /// Builds the Cache-Control header value.
    pub fn build(self: CacheControl, allocator: std.mem.Allocator) ![]u8 {
        var parts: std.ArrayListUnmanaged([]const u8) = .{};
        defer parts.deinit(allocator);

        if (self.public) try parts.append(allocator, "public");
        if (self.private) try parts.append(allocator, "private");
        if (self.no_cache) try parts.append(allocator, "no-cache");
        if (self.no_store) try parts.append(allocator, "no-store");
        if (self.no_transform) try parts.append(allocator, "no-transform");
        if (self.must_revalidate) try parts.append(allocator, "must-revalidate");
        if (self.proxy_revalidate) try parts.append(allocator, "proxy-revalidate");
        if (self.immutable) try parts.append(allocator, "immutable");

        var result: std.ArrayListUnmanaged(u8) = .{};
        const writer = result.writer(allocator);

        for (parts.items, 0..) |part, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(part);
        }

        if (self.max_age) |age| {
            if (parts.items.len > 0) try writer.writeAll(", ");
            try writer.print("max-age={d}", .{age});
        }

        if (self.s_maxage) |age| {
            try writer.print(", s-maxage={d}", .{age});
        }

        if (self.stale_while_revalidate) |age| {
            try writer.print(", stale-while-revalidate={d}", .{age});
        }

        if (self.stale_if_error) |age| {
            try writer.print(", stale-if-error={d}", .{age});
        }

        return result.toOwnedSlice(allocator);
    }

    /// Preset: No caching.
    pub const none: CacheControl = .{
        .no_store = true,
        .no_cache = true,
        .must_revalidate = true,
    };

    /// Preset: Private caching.
    pub fn privateCaching(max_age: u32) CacheControl {
        return .{
            .private = true,
            .max_age = max_age,
        };
    }

    /// Preset: Public caching.
    pub fn publicCaching(max_age: u32) CacheControl {
        return .{
            .public = true,
            .max_age = max_age,
        };
    }

    /// Preset: Immutable static assets.
    pub fn immutableAsset(max_age: u32) CacheControl {
        return .{
            .public = true,
            .max_age = max_age,
            .immutable = true,
        };
    }

    /// Preset: Stale-while-revalidate pattern.
    pub fn staleWhileRevalidate(max_age: u32, stale_time: u32) CacheControl {
        return .{
            .public = true,
            .max_age = max_age,
            .stale_while_revalidate = stale_time,
        };
    }
};

/// ETag generator.
pub const ETag = struct {
    /// Generates weak ETag from content.
    pub fn weak(content: []const u8) [16]u8 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(content);
        const hash = hasher.final();

        var result: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&result, "W/\"{x:0>8}\"", .{@as(u32, @truncate(hash))}) catch {};
        return result;
    }

    /// Generates strong ETag from content.
    pub fn strong(content: []const u8) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(content);
        var hash: [32]u8 = undefined;
        hasher.final(&hash);

        var result: [32]u8 = undefined;
        const encoder = std.base64.standard;
        _ = encoder.encode(&result, hash[0..16]);
        return result;
    }

    /// Checks if ETag matches.
    pub fn matches(etag: []const u8, if_none_match: []const u8) bool {
        if (std.mem.eql(u8, if_none_match, "*")) return true;

        // Handle multiple ETags
        var iter = std.mem.splitScalar(u8, if_none_match, ',');
        while (iter.next()) |tag| {
            const trimmed = std.mem.trim(u8, tag, " ");
            if (std.mem.eql(u8, trimmed, etag)) return true;

            // Weak comparison
            if (std.mem.startsWith(u8, trimmed, "W/")) {
                if (std.mem.eql(u8, trimmed[2..], etag)) return true;
            }
        }

        return false;
    }
};

/// Default cache configurations.
pub const Defaults = struct {
    pub const standard: CacheConfig = .{};

    pub const high_memory: CacheConfig = .{
        .max_entries = 100000,
        .cleanup_interval_ms = 120000,
    };

    pub const low_memory: CacheConfig = .{
        .max_entries = 1000,
        .default_ttl_ms = 60000,
        .cleanup_interval_ms = 30000,
    };

    pub const session: CacheConfig = .{
        .max_entries = 50000,
        .default_ttl_ms = 1800000, // 30 minutes
    };
};

test "cache basic operations" {
    const allocator = std.testing.allocator;
    var cache = Cache(u32, []const u8).init(allocator, .{ .max_entries = 10 });
    defer cache.deinit();

    try cache.set(1, "hello", null);
    try cache.set(2, "world", null);

    try std.testing.expectEqualStrings("hello", cache.get(1).?);
    try std.testing.expectEqualStrings("world", cache.get(2).?);
    try std.testing.expect(cache.get(3) == null);
}

test "cache ttl expiration" {
    const allocator = std.testing.allocator;
    var cache = Cache(u32, []const u8).init(allocator, .{});
    defer cache.deinit();

    try cache.set(1, "expires", 1); // 1ms TTL
    std.Thread.sleep(10 * std.time.ns_per_ms);

    try std.testing.expect(cache.get(1) == null);
}

test "cache lru eviction" {
    const allocator = std.testing.allocator;
    var cache = Cache(u32, []const u8).init(allocator, .{ .max_entries = 3 });
    defer cache.deinit();

    try cache.set(1, "a", null);
    try cache.set(2, "b", null);
    try cache.set(3, "c", null);

    // Access 1 and 2 to make 3 the LRU
    _ = cache.get(1);
    _ = cache.get(2);

    // This should evict 3
    try cache.set(4, "d", null);

    try std.testing.expect(cache.get(3) == null);
    try std.testing.expect(cache.get(1) != null);
}

test "cache control builder" {
    const allocator = std.testing.allocator;

    const cc = CacheControl.publicCaching(3600);
    const value = try cc.build(allocator);
    defer allocator.free(value);

    try std.testing.expect(std.mem.indexOf(u8, value, "public") != null);
    try std.testing.expect(std.mem.indexOf(u8, value, "max-age=3600") != null);
}
