<div align="center">

<img  alt="logo" src="https://github.com/user-attachments/assets/8c73f119-df49-46ac-ab5c-9dd5d216da4d" />

<a href="https://muhammad-fiaz.github.io/api.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.15.0+-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/api.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/api.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/api.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/api.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/api.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/api.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/api.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/api.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/api.zig/blob/main/LICENSE"><img src="https://img.shields.io/github/license/muhammad-fiaz/api.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/api.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/api.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/api.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/api.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/github.com/muhammad-fiaz/api.zig/"><img src="https://hits.sh/github.com/muhammad-fiaz/api.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>High-performance, multi-threaded HTTP API framework for Zig - build blazing-fast APIs with compile-time safety.</em></p>

<b>📚 <a href="https://muhammad-fiaz.github.io/api.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/api.zig/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/api.zig/guide/quick-start">Quick Start</a> |
<a href="https://github.com/muhammad-fiaz/api.zig/blob/main/CONTRIBUTING.md">Contributing</a></b>

</div>

---

> [!WARNING]
> This project has been discontinued and replaced by [httpx.zig](https://github.com/muhammad-fiaz/httpx.zig).
> Please use **httpx.zig** for new projects.

## ✨ Features

- 🚀 **High Performance** - Zero runtime reflection, compile-time route validation
- ⚡ **Multi-Threaded** - Configurable thread pools for concurrent request handling
- 📝 **Automatic OpenAPI** - Auto-generated OpenAPI 3.1 specification
- 🎨 **Swagger UI & ReDoc** - Built-in interactive API documentation (Swagger UI 5.31.0, ReDoc 2.5.2)
- 🔒 **Type Safety** - Full compile-time type checking for routes and handlers
- 🔄 **Concurrency** - Thread-safe request handling with atomic counters
- 🎯 **GraphQL Support** - Built-in GraphQL Playground with GraphiQL 3.8.3
- 📦 **Zero Dependencies** - Pure Zig implementation
- 🌐 **Cross-Platform** - Linux, Windows, macOS

## UI Preview

<table>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/2a9141a4-7df1-45fa-846c-daafd2827585" />
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/5fc85cce-e346-4fe6-b495-c1931550955e" />
    </td>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/d698a2ab-ea85-4fc0-82a6-0ac82a6bb310" />
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/47ae9990-0026-4339-877f-0378f8922a2a" />
    </td>
  </tr>
</table>





## 📦 Installation

Add `api.zig` to your `build.zig.zon`:

```bash
zig fetch --save https://github.com/muhammad-fiaz/api.zig/archive/refs/heads/main.tar.gz
```

Then in your `build.zig`:

```zig
const api = b.dependency("api", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("api", api.module("api"));
```

## 🚀 Quick Start

```zig
const std = @import("std");
const api = @import("api");

fn hello() api.Response {
    return api.Response.jsonRaw("{\"message\":\"Hello, World!\"}");
}

fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1,\"name\":\"John Doe\"}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = api.App.init(allocator, .{
        .title = "My API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/", hello);
    try app.get("/users/{id}", getUser);

    // Run with 4 worker threads
    try app.run(.{ .port = 8000, .num_threads = 4 });
}
```

Run your server:

```bash
zig build run
```

Then visit:

- **http://localhost:8000/** — Your API
- **http://localhost:8000/docs** — Swagger UI
- **http://localhost:8000/redoc** — ReDoc

## ⚡ Multi-Threading

api.zig supports configurable thread pools for maximum performance:

```zig
// Single-threaded mode (default)
try app.run(.{ .port = 8000 });

// Multi-threaded with 4 workers
try app.run(.{ .port = 8000, .num_threads = 4 });

// Auto-detect CPU count
try app.run(.{ .port = 8000, .num_threads = null });
```

## 📚 API Reference

### HTTP Methods

```zig
try app.get("/resource", handler);
try app.post("/resource", handler);
try app.put("/resource/{id}", handler);
try app.delete("/resource/{id}", handler);
try app.patch("/resource/{id}", handler);
```

### Path Parameters

```zig
fn getUser(ctx: *api.Context) api.Response {
    const user_id = ctx.param("id") orelse "0";
    // Use user_id...
}

try app.get("/users/{id}", getUser);
```

### Response Types

```zig
// JSON response
api.Response.jsonRaw("{\"key\":\"value\"}");

// Text response
api.Response.text("Hello, World!");

// HTML response
api.Response.html("<h1>Hello</h1>");

// Error response
api.Response.err(.not_found, "{\"error\":\"Not found\"}");

// Redirect
api.Response.redirect("/new-location");
```

### Builder Pattern

```zig
api.Response.text("Created")
    .setStatus(.created)
    .setHeader("X-Custom", "value")
    .withCors("*");
```

## 🧪 Testing

Run the test suite:

```bash
zig build test
```

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💖 Support

If you find this project helpful, please consider:

- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting new features
- 🔀 Submitting pull requests
