# Logger

Cross-platform colorful logging for api.zig framework.  
Works on **Windows** (cmd, PowerShell, VS Code), **Linux**, and **macOS**.

## Import

```zig
const api = @import("api");
const Logger = api.Logger;
```

## LogConfig

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `level` | `Level` | `.info` | Minimum log level |
| `colors` | `bool` | `true` | Enable ANSI colors |
| `timestamps` | `bool` | `false` | Include timestamps |
| `show_source` | `bool` | `false` | Show source location |
| `format` | `Format` | `.simple` | Output format |
| `output` | `Output` | `.stderr` | Output destination |
| `include_thread_id` | `bool` | `false` | Show thread ID |

## Level

Log levels in order of severity:

| Level | Color | Value | Description |
|-------|-------|-------|-------------|
| `.debug` | Cyan | 0 | Detailed debugging |
| `.info` | Green | 1 | General information |
| `.warn` | Yellow | 2 | Warning messages |
| `.err` | Red | 3 | Error messages |

```zig
pub const Level = enum {
    debug,
    info,
    warn,
    err,
};
```

### Level Methods

#### toString

```zig
pub fn toString(self: Level) []const u8
```

Returns level name string.

#### color

```zig
pub fn color(self: Level) []const u8
```

Returns ANSI color code for the level.

## Logger Methods

| Method | Description |
|--------|-------------|
| `init(allocator)` | Create logger instance |
| `deinit()` | Clean up resources |
| `debug(msg, src)` | Log debug message |
| `info(msg, src)` | Log info message |
| `warn(msg, src)` | Log warning message |
| `err(msg, src)` | Log error message |
| `success(msg)` | Log success message |
| `debugf(fmt, args, src)` | Log formatted debug |
| `infof(fmt, args, src)` | Log formatted info |
| `warnf(fmt, args, src)` | Log formatted warning |
| `errf(fmt, args, src)` | Log formatted error |
| `setLevel(level)` | Set minimum level |
| `setColors(bool)` | Enable/disable colors |

### Creating a Logger

```zig
const logger = try Logger.init(allocator);
defer logger.deinit();
```

### Logging Methods

```zig
try logger.debug("Debug message", null);
try logger.info("Info message", null);
try logger.warn("Warning message", null);
try logger.err("Error message", null);
try logger.success("Success message");
```

### Formatted Logging

```zig
try logger.debugf("Value: {d}", .{42}, null);
try logger.infof("User: {s}", .{username}, null);
try logger.warnf("Timeout: {d}ms", .{timeout}, null);
try logger.errf("Error: {}", .{err}, null);
```

### Configuration

#### setLevel

```zig
pub fn setLevel(self: *Logger, level: Level) void
```

Sets minimum log level.

```zig
logger.setLevel(.debug);  // Show all logs
logger.setLevel(.warn);   // Show warn and err only
```

#### setColors

```zig
pub fn setColors(self: *Logger, enabled: bool) void
```

Enable/disable colored output.

```zig
logger.setColors(false);  // Disable colors
```

## Cross-Platform Colors

api.zig automatically enables ANSI color support on Windows terminals:

- **Windows Command Prompt**: Virtual Terminal Processing enabled
- **Windows PowerShell**: Virtual Terminal Processing enabled
- **VS Code Terminal**: Native support
- **Linux/macOS**: Native ANSI support

## Color Constants

```zig
const Color = api.logger.Color;

Color.reset     // Reset all formatting
Color.red       // Red text
Color.green     // Green text
Color.yellow    // Yellow text
Color.blue      // Blue text
Color.cyan      // Cyan text
Color.magenta   // Magenta text
Color.bold      // Bold text
```

## Output Format

```
[OK] Server started
[INFO] GET /users
[WARN] High memory usage
[ERROR] Connection failed
[DEBUG] Request body: {...}
```

## Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const logger = try api.Logger.init(gpa.allocator());
    defer logger.deinit();
    
    try logger.success("Application started");
    try logger.info("Initializing...", null);
    try logger.infof("Port: {d}", .{8000}, null);
    try logger.warn("Debug mode enabled", null);
}
```

## Handler Example

```zig
fn handler(ctx: *api.Context) api.Response {
    ctx.logger.infof("{s} {s}", .{
        ctx.method().toString(),
        ctx.path(),
    }, null) catch {};
    
    return api.Response.text("OK");
}
```

## Access Logging

Enable in run configuration:

```zig
try app.run(.{
    .port = 8000,
    .access_log = true,
});
```

Output:

```
[INFO] GET /
[INFO] POST /users
[INFO] GET /users/123
```
