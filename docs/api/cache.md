# Cache Module

The Cache module provides high-performance caching capabilities including LRU caching, TTL expiration, HTTP response caching, and ETag support.

## Overview

```zig
const cache = @import("api").cache;
```

## Quick Start

```zig
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable response caching
    try app.enableCaching(.{
        .max_entries = 1000,
        .default_ttl_seconds = 300, // 5 minutes
    });

    app.router.get("/api/data", dataHandler);

    try app.listen(.{ .port = 8080 });
}
```

## Generic LRU Cache

### Creating a Cache

```zig
// Cache with string keys and any value type
var my_cache = cache.Cache([]const u8, MyStruct).init(allocator, .{
    .max_entries = 10000,
    .default_ttl_ms = 300000, // 5 minutes
});
defer my_cache.deinit();
```

### CacheConfig

```zig
const CacheConfig = struct {
    // Maximum number of entries (0 = unlimited)
    max_entries: usize = 0,
    
    // Default TTL in milliseconds (null = no expiration)
    default_ttl_ms: ?u64 = null,
    
    // Enable LRU eviction when max_entries is reached
    eviction_policy: EvictionPolicy = .lru,
    
    // Stats collection
    enable_stats: bool = true,
};

const EvictionPolicy = enum {
    lru,     // Least Recently Used
    lfu,     // Least Frequently Used
    fifo,    // First In First Out
    random,  // Random eviction
};
```

### Basic Operations

```zig
// Set with default TTL
try my_cache.set("key", value, null);

// Set with custom TTL (5 seconds)
try my_cache.set("key", value, 5000);

// Get value
if (my_cache.get("key")) |value| {
    // Use value
}

// Check if key exists
if (my_cache.contains("key")) {
    // Key exists
}

// Remove key
my_cache.remove("key");

// Clear all entries
my_cache.clear();

// Get number of entries
const count = my_cache.count();
```

### TTL Expiration

```zig
// Set with 1 second TTL
try my_cache.set("temp_key", "temporary", 1000);

// Value exists
std.debug.assert(my_cache.get("temp_key") != null);

// Wait for expiration
std.time.sleep(1100 * std.time.ns_per_ms);

// Value expired
std.debug.assert(my_cache.get("temp_key") == null);
```

### LRU Eviction

```zig
var cache = cache.Cache(u32, []const u8).init(allocator, .{
    .max_entries = 3,
});

try cache.set(1, "a", null);
try cache.set(2, "b", null);
try cache.set(3, "c", null);

// Access 1 and 2 to make 3 the LRU
_ = cache.get(1);
_ = cache.get(2);

// This will evict key 3 (LRU)
try cache.set(4, "d", null);

std.debug.assert(cache.get(3) == null);  // Evicted
std.debug.assert(cache.get(1) != null);  // Still present
std.debug.assert(cache.get(4) != null);  // New entry
```

## Response Cache

The ResponseCache provides HTTP-aware caching for API responses.

### Creating a Response Cache

```zig
var response_cache = cache.ResponseCache.init(allocator, .{
    .max_entries = 1000,
    .default_ttl_seconds = 300,
    .vary_headers = &.{"Accept", "Accept-Encoding"},
});
defer response_cache.deinit();
```

### Response Cache Config

```zig
const ResponseCacheConfig = struct {
    max_entries: usize = 1000,
    default_ttl_seconds: u32 = 300,
    max_body_size: usize = 1024 * 1024, // 1MB
    
    // Headers that affect cache key
    vary_headers: []const []const u8 = &.{},
    
    // Methods to cache
    cacheable_methods: []const []const u8 = &.{"GET", "HEAD"},
    
    // Status codes to cache
    cacheable_status_codes: []const u16 = &.{200, 203, 204, 206, 300, 301, 404, 405, 410, 414, 501},
};
```

### Caching Responses

```zig
fn handler(ctx: *api.Context) !void {
    const cache_key = ctx.request.path;
    
    // Check cache first
    if (ctx.app.response_cache) |rc| {
        if (rc.get(cache_key)) |cached| {
            ctx.response.setStatus(cached.status);
            for (cached.headers) |header| {
                ctx.response.setHeader(header.name, header.value);
            }
            try ctx.response.send(cached.body);
            return;
        }
    }

    // Generate response
    const data = try fetchExpensiveData();
    
    // Cache the response
    if (ctx.app.response_cache) |rc| {
        try rc.set(cache_key, .{
            .status = .ok,
            .headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
            .body = data,
        }, 300); // 5 minute TTL
    }

    try ctx.response.json(data);
}
```

## Cache-Control Headers

### CacheControl Builder

```zig
const CacheControl = struct {
    max_age: ?u32 = null,
    s_maxage: ?u32 = null,
    no_cache: bool = false,
    no_store: bool = false,
    no_transform: bool = false,
    must_revalidate: bool = false,
    proxy_revalidate: bool = false,
    public: bool = false,
    private: bool = false,
    immutable: bool = false,
    stale_while_revalidate: ?u32 = null,
    stale_if_error: ?u32 = null,

    pub fn build(self: CacheControl, allocator: std.mem.Allocator) ![]const u8 {
        // Builds Cache-Control header value
    }
};
```

### Using CacheControl

```zig
fn handler(ctx: *api.Context) !void {
    // Public caching for 1 hour
    const cc = cache.CacheControl{
        .public = true,
        .max_age = 3600,
    };
    ctx.response.setHeader("Cache-Control", try cc.build(ctx.allocator));

    // Private, no caching
    const no_cache = cache.CacheControl{
        .private = true,
        .no_cache = true,
        .no_store = true,
    };
    ctx.response.setHeader("Cache-Control", try no_cache.build(ctx.allocator));

    // Immutable asset
    const immutable = cache.CacheControl{
        .public = true,
        .max_age = 31536000, // 1 year
        .immutable = true,
    };
    ctx.response.setHeader("Cache-Control", try immutable.build(ctx.allocator));

    // Stale-while-revalidate
    const swr = cache.CacheControl{
        .max_age = 300,
        .stale_while_revalidate = 86400,
    };
    ctx.response.setHeader("Cache-Control", try swr.build(ctx.allocator));
}
```

## ETag Support

### Generating ETags

```zig
const ETag = struct {
    /// Generates strong ETag from content
    pub fn generate(content: []const u8) [16]u8 {
        var hash: [16]u8 = undefined;
        std.crypto.hash.Md5.hash(content, &hash);
        return hash;
    }

    /// Generates weak ETag
    pub fn generateWeak(content: []const u8) []const u8 {
        const strong = generate(content);
        return std.fmt.allocPrint(allocator, "W/\"{s}\"", .{
            std.fmt.fmtSliceHexLower(&strong)
        });
    }

    /// Formats ETag for header
    pub fn format(hash: [16]u8) [34]u8 {
        var result: [34]u8 = undefined;
        result[0] = '"';
        _ = std.fmt.bufPrint(result[1..33], "{x}", .{hash}) catch unreachable;
        result[33] = '"';
        return result;
    }

    /// Validates If-None-Match header
    pub fn matches(etag: []const u8, if_none_match: []const u8) bool {
        if (std.mem.eql(u8, if_none_match, "*")) return true;
        
        var iter = std.mem.split(u8, if_none_match, ",");
        while (iter.next()) |tag| {
            const trimmed = std.mem.trim(u8, tag, " ");
            if (std.mem.eql(u8, etag, trimmed)) return true;
        }
        return false;
    }
};
```

### Using ETags

```zig
fn handler(ctx: *api.Context) !void {
    const data = try generateResponse();
    const etag = cache.ETag.generate(data);
    const etag_header = cache.ETag.format(etag);

    // Check If-None-Match
    if (ctx.request.getHeader("If-None-Match")) |inm| {
        if (cache.ETag.matches(&etag_header, inm)) {
            ctx.response.setStatus(.not_modified);
            return;
        }
    }

    ctx.response.setHeader("ETag", &etag_header);
    ctx.response.setHeader("Cache-Control", "max-age=3600");
    try ctx.response.send(data);
}
```

## Caching Middleware

### Auto-Cache Middleware

```zig
fn cacheMiddleware(ctx: *api.Context, next: api.NextFn) !void {
    // Only cache GET requests
    if (ctx.request.method != .GET) {
        return next(ctx);
    }

    const cache_key = ctx.request.path;
    const rc = ctx.app.response_cache orelse return next(ctx);

    // Check cache
    if (rc.get(cache_key)) |cached| {
        ctx.response.setHeader("X-Cache", "HIT");
        ctx.response.setStatus(cached.status);
        try ctx.response.send(cached.body);
        return;
    }

    ctx.response.setHeader("X-Cache", "MISS");
    
    // Call handler
    try next(ctx);

    // Cache successful responses
    if (ctx.response.status == .ok) {
        // Store in cache
        rc.set(cache_key, ctx.response.body, null) catch {};
    }
}

app.use(cacheMiddleware);
```

### Conditional Caching

```zig
fn conditionalCacheMiddleware(ctx: *api.Context, next: api.NextFn) !void {
    // Check If-Modified-Since
    if (ctx.request.getHeader("If-Modified-Since")) |ims| {
        const last_modified = getLastModified(ctx.request.path);
        if (parseHttpDate(ims) >= last_modified) {
            ctx.response.setStatus(.not_modified);
            return;
        }
    }

    try next(ctx);

    // Set Last-Modified header
    ctx.response.setHeader("Last-Modified", formatHttpDate(std.time.timestamp()));
}
```

## Cache Statistics

```zig
const CacheStats = struct {
    hits: u64 = 0,
    misses: u64 = 0,
    evictions: u64 = 0,
    entries: usize = 0,
    size_bytes: usize = 0,
    
    pub fn hitRate(self: CacheStats) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

// Get stats
const stats = my_cache.getStats();
std.debug.print("Hit rate: {d:.2}%\n", .{stats.hitRate() * 100});
std.debug.print("Entries: {d}\n", .{stats.entries});
```

## App Integration

### Enabling Caching

```zig
var app = try api.App.init(allocator, .{});

try app.enableCaching(.{
    .max_entries = 5000,
    .default_ttl_seconds = 600,
});

// Access cache from handlers
fn handler(ctx: *api.Context) !void {
    if (ctx.app.response_cache) |rc| {
        // Use response cache
    }
}
```

## Example: API with Caching

```zig
const std = @import("std");
const api = @import("api");
const cache = api.cache;

var user_cache: cache.Cache([]const u8, User) = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Initialize user cache
    user_cache = cache.Cache([]const u8, User).init(allocator, .{
        .max_entries = 10000,
        .default_ttl_ms = 60000, // 1 minute
    });
    defer user_cache.deinit();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable response caching
    try app.enableCaching(.{
        .max_entries = 1000,
        .default_ttl_seconds = 300,
    });

    // Routes with caching
    app.router.get("/api/users/:id", getUserHandler);
    app.router.get("/api/products", productsHandler);

    try app.listen(.{ .port = 8080 });
}

fn getUserHandler(ctx: *api.Context) !void {
    const user_id = ctx.request.param("id") orelse return error.BadRequest;

    // Check user cache
    if (user_cache.get(user_id)) |user| {
        ctx.response.setHeader("X-Cache", "HIT");
        try ctx.response.json(user);
        return;
    }

    // Fetch from database
    const user = try db.getUserById(user_id);
    
    // Store in cache
    try user_cache.set(user_id, user, null);
    
    ctx.response.setHeader("X-Cache", "MISS");
    try ctx.response.json(user);
}

fn productsHandler(ctx: *api.Context) !void {
    // Set cache headers
    const cc = cache.CacheControl{
        .public = true,
        .max_age = 3600,
        .stale_while_revalidate = 86400,
    };
    ctx.response.setHeader("Cache-Control", try cc.build(ctx.allocator));

    // Generate ETag
    const products = try db.getAllProducts();
    const json_data = try std.json.stringifyAlloc(ctx.allocator, products, .{});
    
    const etag = cache.ETag.generate(json_data);
    const etag_header = cache.ETag.format(etag);
    
    // Check If-None-Match
    if (ctx.request.getHeader("If-None-Match")) |inm| {
        if (cache.ETag.matches(&etag_header, inm)) {
            ctx.response.setStatus(.not_modified);
            return;
        }
    }

    ctx.response.setHeader("ETag", &etag_header);
    try ctx.response.json(products);
}
```

## Cache Invalidation

```zig
// Invalidate single key
my_cache.remove("user:123");

// Invalidate by pattern (manual)
fn invalidatePattern(comptime prefix: []const u8) void {
    var iter = my_cache.iterator();
    while (iter.next()) |entry| {
        if (std.mem.startsWith(u8, entry.key, prefix)) {
            my_cache.remove(entry.key);
        }
    }
}

// Invalidate all users
invalidatePattern("user:");

// Clear all cache
my_cache.clear();
```

## Best Practices

1. **Set appropriate TTLs** - Match TTL to data freshness requirements
2. **Use ETags for validation** - Reduces bandwidth for unchanged content
3. **Monitor cache hit rates** - Aim for >80% hit rate
4. **Size cache appropriately** - Balance memory usage vs hit rate
5. **Invalidate on mutations** - Clear cache when data changes
6. **Use Vary headers correctly** - Prevent serving wrong cached content
7. **Consider stale-while-revalidate** - Improve perceived performance

## See Also

- [Response Module](response.md) - For response handling
- [Middleware Module](middleware.md) - For caching middleware
- [Metrics Module](metrics.md) - For cache metrics
