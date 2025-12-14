# Installation

## Using Zig Package Manager

Add api.zig to your project using Zig's built-in package manager:

```bash
zig fetch --save https://github.com/muhammad-fiaz/api.zig/archive/refs/heads/main.tar.gz
```

Then add this to your `build.zig`:

```zig
const api = b.dependency("api", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("api", api.module("api"));
```

## Manual Installation

Clone the repository:

```bash
git clone https://github.com/muhammad-fiaz/api.zig.git
```

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .api = .{
        .path = "path/to/api.zig",
    },
},
```

## Requirements

- Zig 0.15.0 or later
- No external dependencies

## Verifying Installation

Create a test file:

```zig
const api = @import("api");

pub fn main() !void {
    _ = api.getVersion();
}
```

Build:

```bash
zig build
```

If it compiles successfully, you're ready to go!
