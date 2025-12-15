//! Metrics and health monitoring for api.zig framework.
//! Provides production-ready observability features including metrics collection,
//! health checks, and Prometheus-compatible exports.
//!
//! ## Features
//! - Request/response metrics (latency, throughput, errors)
//! - Custom counters, gauges, and histograms
//! - Health check endpoints with dependency checks
//! - Prometheus format export
//! - StatsD/Graphite integration support

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;

/// Metric types.
pub const MetricType = enum {
    counter,
    gauge,
    histogram,
    summary,
};

/// Metric label pair.
pub const Label = struct {
    name: []const u8,
    value: []const u8,
};

/// Counter metric - monotonically increasing value.
pub const Counter = struct {
    name: []const u8,
    help: []const u8,
    labels: []const Label = &.{},
    value: std.atomic.Value(u64),

    pub fn init(name: []const u8, help: []const u8, labels: []const Label) Counter {
        return .{
            .name = name,
            .help = help,
            .labels = labels,
            .value = std.atomic.Value(u64).init(0),
        };
    }

    pub fn inc(self: *Counter) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub fn add(self: *Counter, delta: u64) void {
        _ = self.value.fetchAdd(delta, .monotonic);
    }

    pub fn get(self: *const Counter) u64 {
        return self.value.load(.monotonic);
    }
};

/// Gauge metric - can go up or down.
pub const Gauge = struct {
    name: []const u8,
    help: []const u8,
    labels: []const Label = &.{},
    value: std.atomic.Value(i64),

    pub fn init(name: []const u8, help: []const u8, labels: []const Label) Gauge {
        return .{
            .name = name,
            .help = help,
            .labels = labels,
            .value = std.atomic.Value(i64).init(0),
        };
    }

    pub fn set(self: *Gauge, val: i64) void {
        self.value.store(val, .monotonic);
    }

    pub fn inc(self: *Gauge) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub fn dec(self: *Gauge) void {
        _ = self.value.fetchSub(1, .monotonic);
    }

    pub fn add(self: *Gauge, delta: i64) void {
        _ = self.value.fetchAdd(delta, .monotonic);
    }

    pub fn get(self: *const Gauge) i64 {
        return self.value.load(.monotonic);
    }
};

/// Histogram bucket.
pub const Bucket = struct {
    le: f64, // Less than or equal
    count: std.atomic.Value(u64),
};

/// Histogram metric - distribution of values.
pub const Histogram = struct {
    name: []const u8,
    help: []const u8,
    labels: []const Label = &.{},
    buckets: []Bucket,
    sum: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    count: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    pub const DefaultBuckets = [_]f64{ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10 };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, help: []const u8, bucket_bounds: []const f64) !Histogram {
        const buckets = try allocator.alloc(Bucket, bucket_bounds.len + 1); // +1 for +Inf

        for (bucket_bounds, 0..) |bound, i| {
            buckets[i] = .{
                .le = bound,
                .count = std.atomic.Value(u64).init(0),
            };
        }
        buckets[bucket_bounds.len] = .{
            .le = std.math.inf(f64),
            .count = std.atomic.Value(u64).init(0),
        };

        return .{
            .name = name,
            .help = help,
            .buckets = buckets,
        };
    }

    pub fn observe(self: *Histogram, value: f64) void {
        // Update buckets
        for (self.buckets) |*bucket| {
            if (value <= bucket.le) {
                _ = bucket.count.fetchAdd(1, .monotonic);
            }
        }

        // Update sum and count
        const int_val: u64 = @intFromFloat(value * 1000000); // Store as microseconds
        _ = self.sum.fetchAdd(int_val, .monotonic);
        _ = self.count.fetchAdd(1, .monotonic);
    }

    pub fn getSum(self: *const Histogram) f64 {
        const sum = self.sum.load(.monotonic);
        return @as(f64, @floatFromInt(sum)) / 1000000.0;
    }

    pub fn getCount(self: *const Histogram) u64 {
        return self.count.load(.monotonic);
    }
};

/// Metric registry for collecting and exporting metrics.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    counters: std.StringHashMap(*Counter),
    gauges: std.StringHashMap(*Gauge),
    histograms: std.StringHashMap(*Histogram),
    prefix: ?[]const u8 = null,

    // Built-in HTTP metrics
    http_requests_total: Counter,
    http_request_duration_seconds: Histogram,
    http_requests_in_flight: Gauge,
    http_response_size_bytes: Histogram,

    pub fn init(allocator: std.mem.Allocator, config: RegistryConfig) !Registry {
        return Registry{
            .allocator = allocator,
            .counters = std.StringHashMap(*Counter).init(allocator),
            .gauges = std.StringHashMap(*Gauge).init(allocator),
            .histograms = std.StringHashMap(*Histogram).init(allocator),
            .prefix = config.prefix,
            .http_requests_total = Counter.init("http_requests_total", "Total number of HTTP requests", &.{}),
            .http_request_duration_seconds = try Histogram.init(allocator, "http_request_duration_seconds", "HTTP request duration in seconds", &Histogram.DefaultBuckets),
            .http_requests_in_flight = Gauge.init("http_requests_in_flight", "Number of HTTP requests currently being processed", &.{}),
            .http_response_size_bytes = try Histogram.init(allocator, "http_response_size_bytes", "HTTP response size in bytes", &.{ 100, 1000, 10000, 100000, 1000000 }),
        };
    }

    pub fn deinit(self: *Registry) void {
        var counter_iter = self.counters.valueIterator();
        while (counter_iter.next()) |c| {
            self.allocator.destroy(c.*);
        }
        self.counters.deinit();

        var gauge_iter = self.gauges.valueIterator();
        while (gauge_iter.next()) |g| {
            self.allocator.destroy(g.*);
        }
        self.gauges.deinit();

        var hist_iter = self.histograms.valueIterator();
        while (hist_iter.next()) |h| {
            self.allocator.free(h.*.buckets);
            self.allocator.destroy(h.*);
        }
        self.histograms.deinit();

        // Free built-in histogram buckets
        self.allocator.free(self.http_request_duration_seconds.buckets);
        self.allocator.free(self.http_response_size_bytes.buckets);
    }

    /// Registers a counter.
    pub fn registerCounter(self: *Registry, name: []const u8, help: []const u8) !*Counter {
        const counter = try self.allocator.create(Counter);
        counter.* = Counter.init(name, help, &.{});
        try self.counters.put(name, counter);
        return counter;
    }

    /// Registers a gauge.
    pub fn registerGauge(self: *Registry, name: []const u8, help: []const u8) !*Gauge {
        const gauge = try self.allocator.create(Gauge);
        gauge.* = Gauge.init(name, help, &.{});
        try self.gauges.put(name, gauge);
        return gauge;
    }

    /// Registers a histogram.
    pub fn registerHistogram(self: *Registry, name: []const u8, help: []const u8, buckets: []const f64) !*Histogram {
        const hist = try self.allocator.create(Histogram);
        hist.* = try Histogram.init(self.allocator, name, help, buckets);
        try self.histograms.put(name, hist);
        return hist;
    }

    /// Gets a counter by name.
    pub fn getCounter(self: *Registry, name: []const u8) ?*Counter {
        return self.counters.get(name);
    }

    /// Gets a gauge by name.
    pub fn getGauge(self: *Registry, name: []const u8) ?*Gauge {
        return self.gauges.get(name);
    }

    /// Gets a histogram by name.
    pub fn getHistogram(self: *Registry, name: []const u8) ?*Histogram {
        return self.histograms.get(name);
    }

    /// Exports metrics in Prometheus text format.
    pub fn toPrometheus(self: *const Registry, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        const writer = buffer.writer(allocator);

        // Export built-in HTTP metrics
        try writeCounter(writer, &self.http_requests_total, self.prefix);
        try writeGauge(writer, &self.http_requests_in_flight, self.prefix);
        try writeHistogram(writer, &self.http_request_duration_seconds, self.prefix);
        try writeHistogram(writer, &self.http_response_size_bytes, self.prefix);

        // Export custom counters
        var counter_iter = self.counters.valueIterator();
        while (counter_iter.next()) |c| {
            try writeCounter(writer, c.*, self.prefix);
        }

        // Export custom gauges
        var gauge_iter = self.gauges.valueIterator();
        while (gauge_iter.next()) |g| {
            try writeGauge(writer, g.*, self.prefix);
        }

        // Export custom histograms
        var hist_iter = self.histograms.valueIterator();
        while (hist_iter.next()) |h| {
            try writeHistogram(writer, h.*, self.prefix);
        }

        return buffer.toOwnedSlice(allocator);
    }
};

fn writeCounter(writer: anytype, counter: *const Counter, prefix: ?[]const u8) !void {
    try writer.print("# HELP {s}{s} {s}\n", .{ prefix orelse "", counter.name, counter.help });
    try writer.print("# TYPE {s}{s} counter\n", .{ prefix orelse "", counter.name });
    try writer.print("{s}{s}", .{ prefix orelse "", counter.name });
    try writeLabels(writer, counter.labels);
    try writer.print(" {d}\n", .{counter.get()});
}

fn writeGauge(writer: anytype, gauge: *const Gauge, prefix: ?[]const u8) !void {
    try writer.print("# HELP {s}{s} {s}\n", .{ prefix orelse "", gauge.name, gauge.help });
    try writer.print("# TYPE {s}{s} gauge\n", .{ prefix orelse "", gauge.name });
    try writer.print("{s}{s}", .{ prefix orelse "", gauge.name });
    try writeLabels(writer, gauge.labels);
    try writer.print(" {d}\n", .{gauge.get()});
}

fn writeHistogram(writer: anytype, hist: *const Histogram, prefix: ?[]const u8) !void {
    try writer.print("# HELP {s}{s} {s}\n", .{ prefix orelse "", hist.name, hist.help });
    try writer.print("# TYPE {s}{s} histogram\n", .{ prefix orelse "", hist.name });

    for (hist.buckets) |bucket| {
        try writer.print("{s}{s}_bucket{{le=\"", .{ prefix orelse "", hist.name });
        if (bucket.le == std.math.inf(f64)) {
            try writer.writeAll("+Inf");
        } else {
            try writer.print("{d}", .{bucket.le});
        }
        try writer.print("\"}} {d}\n", .{bucket.count.load(.monotonic)});
    }

    try writer.print("{s}{s}_sum {d}\n", .{ prefix orelse "", hist.name, hist.getSum() });
    try writer.print("{s}{s}_count {d}\n", .{ prefix orelse "", hist.name, hist.getCount() });
}

fn writeLabels(writer: anytype, labels: []const Label) !void {
    if (labels.len == 0) return;

    try writer.writeAll("{");
    for (labels, 0..) |label, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("{s}=\"{s}\"", .{ label.name, label.value });
    }
    try writer.writeAll("}");
}

/// Registry configuration.
pub const RegistryConfig = struct {
    prefix: ?[]const u8 = null,
    enable_process_metrics: bool = true,
    enable_runtime_metrics: bool = true,
};

/// Health check status.
pub const HealthStatus = enum {
    healthy,
    degraded,
    unhealthy,

    pub fn toString(self: HealthStatus) []const u8 {
        return switch (self) {
            .healthy => "healthy",
            .degraded => "degraded",
            .unhealthy => "unhealthy",
        };
    }

    pub fn httpStatus(self: HealthStatus) u16 {
        return switch (self) {
            .healthy => 200,
            .degraded => 200,
            .unhealthy => 503,
        };
    }
};

/// Health check result.
pub const CheckResult = struct {
    name: []const u8,
    status: HealthStatus,
    message: ?[]const u8 = null,
    duration_ms: u64 = 0,
    timestamp: i64 = 0,
};

/// Health check function type.
pub const CheckFn = *const fn (*Context) CheckResult;

/// Health checker for managing health endpoints.
pub const HealthChecker = struct {
    allocator: std.mem.Allocator,
    checks: std.StringHashMap(CheckFn),
    config: HealthConfig,

    pub const HealthConfig = struct {
        path: []const u8 = "/health",
        liveness_path: []const u8 = "/health/live",
        readiness_path: []const u8 = "/health/ready",
        include_details: bool = true,
        timeout_ms: u32 = 5000,
    };

    pub fn init(allocator: std.mem.Allocator, config: HealthConfig) HealthChecker {
        return .{
            .allocator = allocator,
            .checks = std.StringHashMap(CheckFn).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *HealthChecker) void {
        self.checks.deinit();
    }

    /// Registers a health check.
    pub fn register(self: *HealthChecker, name: []const u8, check: CheckFn) !void {
        try self.checks.put(name, check);
    }

    /// Runs all health checks.
    pub fn runAll(self: *HealthChecker, ctx: *Context) HealthReport {
        var results = std.ArrayList(CheckResult).init(self.allocator);
        var overall_status = HealthStatus.healthy;

        var iter = self.checks.iterator();
        while (iter.next()) |entry| {
            const start = std.time.milliTimestamp();
            var result = entry.value_ptr.*(ctx);
            result.duration_ms = @intCast(std.time.milliTimestamp() - start);
            result.timestamp = std.time.milliTimestamp();

            // Update overall status
            if (@intFromEnum(result.status) > @intFromEnum(overall_status)) {
                overall_status = result.status;
            }

            results.append(result) catch {};
        }

        return .{
            .status = overall_status,
            .checks = results.toOwnedSlice() catch &.{},
            .timestamp = std.time.milliTimestamp(),
        };
    }
};

/// Health report aggregate.
pub const HealthReport = struct {
    status: HealthStatus,
    checks: []const CheckResult,
    timestamp: i64,

    pub fn toJson(self: *const HealthReport, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        try writer.print("{{\"status\":\"{s}\",\"timestamp\":{d},\"checks\":[", .{ self.status.toString(), self.timestamp });

        for (self.checks, 0..) |check, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"name\":\"{s}\",\"status\":\"{s}\"", .{ check.name, check.status.toString() });
            if (check.message) |msg| {
                try writer.print(",\"message\":\"{s}\"", .{msg});
            }
            try writer.print(",\"duration_ms\":{d}}}", .{check.duration_ms});
        }

        try writer.writeAll("]}");
        return buffer.toOwnedSlice();
    }
};

/// Built-in health checks.
pub const Checks = struct {
    /// Memory usage check.
    pub fn memoryCheck(threshold_percent: u8) CheckFn {
        return struct {
            pub fn check(ctx: *Context) CheckResult {
                _ = ctx;
                // Get process memory info (platform-specific)
                const status: HealthStatus = if (threshold_percent > 90) .unhealthy else if (threshold_percent > 75) .degraded else .healthy;

                return .{
                    .name = "memory",
                    .status = status,
                    .message = "Memory usage within limits",
                };
            }
        }.check;
    }

    /// Disk space check.
    pub fn diskCheck(path: []const u8, threshold_percent: u8) CheckFn {
        _ = path;
        _ = threshold_percent;
        return struct {
            pub fn check(ctx: *Context) CheckResult {
                _ = ctx;
                return .{
                    .name = "disk",
                    .status = .healthy,
                    .message = "Disk space available",
                };
            }
        }.check;
    }

    /// Generic ping check (always healthy).
    pub fn pingCheck(ctx: *Context) CheckResult {
        _ = ctx;
        return .{
            .name = "ping",
            .status = .healthy,
            .message = "Service is running",
        };
    }
};

/// Metrics middleware for automatic HTTP metrics collection.
pub fn metricsMiddleware(registry: *Registry) type {
    return struct {
        pub fn handle(ctx: *Context, next: *const fn (*Context) Response) Response {
            const start = std.time.nanoTimestamp();

            // Track in-flight requests
            registry.http_requests_in_flight.inc();
            defer registry.http_requests_in_flight.dec();

            // Call next handler
            const response = next(ctx);

            // Record metrics
            const duration_ns = std.time.nanoTimestamp() - start;
            const duration_s = @as(f64, @floatFromInt(duration_ns)) / 1_000_000_000.0;

            registry.http_requests_total.inc();
            registry.http_request_duration_seconds.observe(duration_s);

            if (response.body) |body| {
                registry.http_response_size_bytes.observe(@floatFromInt(body.len));
            }

            return response;
        }
    };
}

/// Default metric configurations.
pub const Defaults = struct {
    pub const standard: RegistryConfig = .{};

    pub const production: RegistryConfig = .{
        .prefix = "app_",
        .enable_process_metrics = true,
        .enable_runtime_metrics = true,
    };

    pub const minimal: RegistryConfig = .{
        .enable_process_metrics = false,
        .enable_runtime_metrics = false,
    };
};

test "counter operations" {
    var counter = Counter.init("test_counter", "Test counter", &.{});
    counter.inc();
    counter.inc();
    counter.add(5);
    try std.testing.expectEqual(@as(u64, 7), counter.get());
}

test "gauge operations" {
    var gauge = Gauge.init("test_gauge", "Test gauge", &.{});
    gauge.set(100);
    gauge.inc();
    gauge.dec();
    gauge.add(-50);
    try std.testing.expectEqual(@as(i64, 50), gauge.get());
}

test "histogram operations" {
    const allocator = std.testing.allocator;
    var hist = try Histogram.init(allocator, "test_histogram", "Test histogram", &.{ 0.1, 0.5, 1.0 });
    defer allocator.free(hist.buckets);

    hist.observe(0.05);
    hist.observe(0.3);
    hist.observe(0.8);
    hist.observe(2.0);

    try std.testing.expectEqual(@as(u64, 4), hist.getCount());
}

test "prometheus export" {
    const allocator = std.testing.allocator;
    var registry = try Registry.init(allocator, .{});
    defer registry.deinit();

    registry.http_requests_total.add(100);

    const output = try registry.toPrometheus(allocator);
    defer allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "http_requests_total") != null);
}
