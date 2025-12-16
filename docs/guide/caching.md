# Caching

api.zig provides in-memory caching primitives geared for HTTP responses and application data.

## Features

- LRU eviction
- TTL expiration
- Response caching middleware with ETag support

## Example

```zig
var cache = ResponseCache.init(allocator, .{ .max_size = 1000 });
app.addMiddleware(cache.cacheMiddleware(&cache));
```

See `src/cache.zig` for cache configuration, invalidation, and helper utilities.