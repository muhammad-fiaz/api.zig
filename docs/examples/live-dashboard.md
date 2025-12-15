# Live Dashboard Example

A real-time metrics dashboard using Server-Sent Events (SSE) with api.zig.

## Full Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Live Dashboard",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Dashboard page
    app.router.get("/", serveDashboard);
    
    // SSE endpoint for live metrics
    app.router.get("/events", streamMetrics);
    
    // API endpoints
    app.router.get("/api/metrics", getMetrics);

    std.debug.print("Dashboard running at http://localhost:8080\n", .{});
    try app.run(.{ .port = 8080 });
}

fn serveDashboard() api.Response {
    return api.Response.html(dashboard_html);
}

fn streamMetrics(ctx: *api.Context) api.Response {
    // Set SSE headers
    ctx.response.setHeader("Content-Type", "text/event-stream");
    ctx.response.setHeader("Cache-Control", "no-cache");
    ctx.response.setHeader("Connection", "keep-alive");
    
    // Start SSE stream
    return ctx.response.stream(struct {
        fn generate() ![]const u8 {
            // Generate metrics data
            var buf: [256]u8 = undefined;
            const metrics = std.fmt.bufPrint(&buf,
                \\data: {{"cpu":{d},"memory":{d},"requests":{d}}}
                \\
                \\
            , .{
                std.crypto.random.intRangeAtMost(u8, 20, 80),
                std.crypto.random.intRangeAtMost(u8, 40, 90),
                std.crypto.random.intRangeAtMost(u16, 100, 1000),
            }) catch return error.FormatError;
            return metrics;
        }
    }.generate, 1000); // Send every 1 second
}

fn getMetrics() api.Response {
    return api.Response.jsonRaw(
        \\{"cpu":45,"memory":62,"requests":523,"uptime":3600}
    );
}

const dashboard_html =
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\<title>Live Dashboard</title>
    \\<style>
    \\body{font-family:sans-serif;background:#1a1a2e;color:#fff;padding:20px}
    \\.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;max-width:900px;margin:0 auto}
    \\.card{background:#16213e;padding:30px;border-radius:10px;text-align:center}
    \\.value{font-size:48px;font-weight:bold;color:#00d4ff}
    \\.label{color:#888;margin-top:10px}
    \\.status{width:10px;height:10px;background:#0f0;border-radius:50%;display:inline-block;margin-right:5px}
    \\</style>
    \\</head>
    \\<body>
    \\<h1><span class="status"></span>Live Dashboard</h1>
    \\<div class="grid">
    \\<div class="card"><div class="value" id="cpu">--</div><div class="label">CPU %</div></div>
    \\<div class="card"><div class="value" id="memory">--</div><div class="label">Memory %</div></div>
    \\<div class="card"><div class="value" id="requests">--</div><div class="label">Requests/sec</div></div>
    \\</div>
    \\<script>
    \\const events = new EventSource('/events');
    \\events.onmessage = (e) => {
    \\  const data = JSON.parse(e.data);
    \\  document.getElementById('cpu').textContent = data.cpu + '%';
    \\  document.getElementById('memory').textContent = data.memory + '%';
    \\  document.getElementById('requests').textContent = data.requests;
    \\};
    \\</script>
    \\</body>
    \\</html>
;
```

## Features

- Server-Sent Events (SSE)
- Real-time metrics updates
- Auto-reconnection
- Low latency

## SSE vs WebSocket

| Feature | SSE | WebSocket |
|---------|-----|-----------|
| Direction | Server → Client | Bidirectional |
| Protocol | HTTP | WebSocket |
| Reconnection | Automatic | Manual |
| Best for | Dashboards, notifications | Chat, gaming |

## Configuration

```zig
ctx.response.stream(generator, .{
    .interval_ms = 1000,
    .keep_alive = true,
    .retry_ms = 3000,
});
```

## See Also

- [Metrics API](/api/metrics)
- [WebSocket Chat](/examples/websocket-chat)
