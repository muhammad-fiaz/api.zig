# Report API

The report module provides error reporting and version checking utilities for api.zig.

## Overview

```zig
const report = @import("api.zig").report;
```

## Constants

### `ISSUES_URL`

GitHub issues URL for bug reports.

```zig
pub const ISSUES_URL = "https://github.com/muhammad-fiaz/api.zig/issues";
```

### `CURRENT_VERSION`

The current library version string.

```zig
pub const CURRENT_VERSION: []const u8 = "1.0.0";
```

## Functions

### `reportInternalError`

Reports an internal library error with instructions for filing a bug report.

```zig
pub fn reportInternalError(message: []const u8) void
```

**Parameters:**
- `message` - Error description

**Example:**
```zig
report.reportInternalError("Unexpected null pointer in router");
```

**Output:**
```
[ERROR] [API.ZIG ERROR] Unexpected null pointer in router
[ERROR] If you believe this is a bug, please report it at: https://github.com/muhammad-fiaz/api.zig/issues
```

### `reportInternalErrorWithCode`

Reports an internal library error with an error value.

```zig
pub fn reportInternalErrorWithCode(err: anyerror) void
```

**Parameters:**
- `err` - The error value to report

**Example:**
```zig
report.reportInternalErrorWithCode(error.OutOfMemory);
```

### `compareVersions`

Compares the current version with a remote version string.

```zig
pub fn compareVersions(latest_raw: []const u8) VersionRelation
```

**Parameters:**
- `latest_raw` - Version string to compare (e.g., "v0.0.2" or "0.0.2")

**Returns:** `VersionRelation` enum

### `checkForUpdates`

Checks GitHub for newer versions (runs once per process).

```zig
pub fn checkForUpdates(allocator: std.mem.Allocator) void
```

**Example:**
```zig
report.checkForUpdates(allocator);
```

**Output (if update available):**
```
[WARN] A new version of api.zig is available: v0.0.2
[WARN] You are using: v0.0.1
[WARN] Update at: https://github.com/muhammad-fiaz/api.zig/releases
```

## Types

### `VersionRelation`

Represents the relationship between local and remote versions.

```zig
pub const VersionRelation = enum {
    local_newer,   // Local version is newer
    equal,         // Versions are the same
    remote_newer,  // Remote version is newer (update available)
    unknown,       // Could not determine
};
```

## Legacy Aliases

For backwards compatibility:

```zig
pub const reportError = reportInternalErrorWithCode;
pub const reportErrorMessage = reportInternalError;
```

## Use Cases

### Reporting Bugs

When you encounter unexpected behavior in api.zig:

```zig
const report = @import("api.zig").report;

fn handleRequest(ctx: *Context) !void {
    // ... your code ...
    
    if (unexpected_condition) {
        report.reportInternalError("Unexpected state in request handler");
        return error.InternalError;
    }
}
```

### Checking for Updates

At application startup:

```zig
const std = @import("std");
const api = @import("api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    // Check for updates (non-blocking, runs in background)
    api.report.checkForUpdates(allocator);
    
    // Start your server...
}
```

## See Also

- [Version](version.md) - Version constants and info
- [Logger](logger.md) - Logging functionality
