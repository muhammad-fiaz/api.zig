# Logging

api.zig includes a cross-platform colorful logging system that works on Windows, Linux, and macOS.

## Log Levels

| Level   | Color  | Description                    |
| ------- | ------ | ------------------------------ |
| `debug` | Cyan   | Detailed debugging information |
| `info`  | Green  | General information messages   |
| `warn`  | Yellow | Warning messages               |
| `err`   | Red    | Error messages                 |

## Using the Logger

### Create a Logger

```zig
const logger = try api.Logger.init(allocator);
defer logger.deinit();
```

### Log Messages

```zig
try logger.debug("Debug message", null);
try logger.info("Server started", null);
try logger.warn("Connection timeout", null);
try logger.err("Failed to process request", null);
try logger.success("Application ready!");
```

### Formatted Messages

```zig
try logger.debugf("Value: {d}", .{42}, null);
try logger.infof("Server started on port {d}", .{port}, null);
try logger.warnf("Connection timeout: {s}", .{address}, null);
try logger.errf("Failed to process request: {}", .{error}, null);
```

## Log Level Filtering

Messages below the minimum level are ignored:

```zig
const logger = try api.Logger.init(allocator);

// Only logs info and above (info, warn, err)
logger.setLevel(.info);

try logger.debug("This won't appear", null);  // Filtered out
try logger.info("This will appear", null);     // Logged
```

### Change Level at Runtime

```zig
var logger = try api.Logger.init(allocator);

// Enable debug logging
logger.setLevel(.debug);

// Back to info
logger.setLevel(.info);
```

## Formatting Options

### Disable Colors

```zig
var logger = try api.Logger.init(allocator);
logger.setColors(false);  // No ANSI colors
```

## Cross-Platform Support

api.zig automatically enables ANSI color support on all platforms:

| Platform           | Support                           |
| ------------------ | --------------------------------- |
| Windows cmd        | Virtual Terminal Processing       |
| Windows PowerShell | Virtual Terminal Processing       |
| VS Code Terminal   | Native support                    |
| Linux              | Native ANSI support               |
| macOS              | Native ANSI support               |

## Output Format

Default colored output format:

```
[OK] Server started
[INFO] GET /users
[INFO] POST /users
[WARN] High memory usage detected
[ERROR] Database connection failed
[DEBUG] Request body: {...}
```

## Access Logging

Enable access logging in server config:

```zig
try app.run(.{
    .port = 8000,
    .access_log = true,  // Enable access logging
});
```

Output:

```
[INFO] GET /users
[INFO] POST /users
[INFO] GET /users/123
[INFO] DELETE /users/123
```

## Print Version Info

```zig
api.report.printVersionInfo();
// api.zig v0.0.1
// Repository: https://github.com/muhammad-fiaz/api.zig
// Docs: https://muhammad-fiaz.github.io/api.zig/
```

## Example: Request Logging

```zig
fn loggedHandler(ctx: *api.Context) api.Response {
    ctx.logger.infof("Processing {s} {s}", .{
        ctx.method().toString(),
        ctx.path(),
    }, null) catch {};

    const response = api.Response.text("ok");

    ctx.logger.infof("Response: {d}", .{
        response.status.toInt(),
    }, null) catch {};

    return response;
}
```

## Example: Standalone Logger

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const logger = try api.Logger.init(gpa.allocator());
    defer logger.deinit();

    try logger.success("Application started");
    try logger.info("Initializing components...", null);
    try logger.infof("Listening on port {d}", .{8000}, null);
}
```
