# Static Files

Static file serving middleware with automatic MIME type detection, index file resolution, and path traversal protection.

## Import

```zig
const api = @import("api");
const static = api.static;
```

## StaticConfig

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `root_path` | `[]const u8` | required | Directory path |
| `url_prefix` | `[]const u8` | `"/"` | URL prefix |
| `index_file` | `?[]const u8` | `"index.html"` | Default index |
| `cache_control` | `?[]const u8` | `null` | Cache header |
| `fallback_handler` | `?Handler` | `null` | 404 handler |

## StaticRouter

Handles serving files from a directory.

```zig
const config = static.StaticConfig{
    .root_path = "public",
    .url_prefix = "/static",
};

const static_router = static.StaticRouter.init(allocator, config);

// Serve specifically
fn serveFile(ctx: *api.Context) api.Response {
    return static_router.serveFile(ctx.allocator, "public/style.css");
}

try app.get("/style.css", serveFile);
```

## MIME Types

| Extension | MIME Type |
|-----------|-----------|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css` |
| `.js` | `application/javascript` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.svg` | `image/svg+xml` |
| `.ico` | `image/x-icon` |
| `.woff`, `.woff2` | `font/woff`, `font/woff2` |
| `.pdf` | `application/pdf` |

## Helpers

### getMimeType

```zig
const mime = api.http.getMimeType("image.png");
// "image/png"
```

### Security

The static file server includes:
- **Path traversal protection**: Blocks `../` attacks
- **Index file resolution**: Auto-serves `index.html`
- **Content-Type detection**: Based on file extension
