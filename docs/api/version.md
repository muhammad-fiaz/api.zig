# Version API

The version module provides library version constants and metadata.

## Overview

```zig
const version_info = @import("api.zig").version;
```

## Constants

### `version`

Current library version.

```zig
pub const version = "1.0.0";
```

### `name`

Library name.

```zig
pub const name = "api.zig";
```

### `repository`

GitHub repository URL.

```zig
pub const repository = "https://github.com/muhammad-fiaz/api.zig";
```

### `docs_url`

Documentation website URL.

```zig
pub const docs_url = "https://muhammad-fiaz.github.io/api.zig/";
```

## Functions

### `getFullVersion`

Returns the full version string with library name.

```zig
pub fn getFullVersion() []const u8
```

**Returns:** `"api.zig v0.0.1"`

**Example:**
```zig
const version_info = @import("api.zig").version;

pub fn main() void {
    std.debug.print("Running {s}\n", .{version_info.getFullVersion()});
}
```

**Output:**
```
Running api.zig v0.0.1
```

### `getRepository`

Returns the GitHub repository URL.

```zig
pub fn getRepository() []const u8
```

**Returns:** `"https://github.com/muhammad-fiaz/api.zig"`

## Usage Examples

### Display Version Info

```zig
const std = @import("std");
const version_info = @import("api.zig").version;

pub fn main() void {
    std.debug.print("=== {s} ===\n", .{version_info.name});
    std.debug.print("Version: {s}\n", .{version_info.version});
    std.debug.print("Docs: {s}\n", .{version_info.docs_url});
    std.debug.print("Repo: {s}\n", .{version_info.repository});
}
```

**Output:**
```
=== api.zig ===
Version: 0.0.1
Docs: https://muhammad-fiaz.github.io/api.zig/
Repo: https://github.com/muhammad-fiaz/api.zig
```

### Version Handler

Create a `/version` endpoint:

```zig
const api = @import("api.zig");
const version_info = api.version;

fn versionHandler(_: *api.Request) api.Response {
    return api.Response.json(.{
        .name = version_info.name,
        .version = version_info.version,
        .docs = version_info.docs_url,
        .repository = version_info.repository,
    }, .{});
}

pub fn main() !void {
    var app = try api.App.init(allocator, .{});
    app.get("/version", versionHandler);
    try app.listen(.{ .port = 8000 });
}
```

**Response:**
```json
{
    "name": "api.zig",
    "version": "0.0.1",
    "docs": "https://muhammad-fiaz.github.io/api.zig/",
    "repository": "https://github.com/muhammad-fiaz/api.zig"
}
```

## Semantic Versioning

api.zig follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: New backwards-compatible features
- **PATCH**: Backwards-compatible bug fixes

Current version breakdown:
- Major: `0` (pre-1.0 development)
- Minor: `0` (initial feature set)
- Patch: `1` (first release)

## See Also

- [Report](report.md) - Version comparison and update checking
- [App](app.md) - Main application API
