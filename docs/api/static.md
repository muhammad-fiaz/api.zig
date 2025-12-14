# Static Files

Static file serving middleware with automatic MIME type detection, index file resolution, and path traversal protection.

## Import

```zig
const api = @import("api");
const static = api.static;
```

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

app.get("/style.css", serveFile);
```

## Helpers

### getMimeType

```zig
const mime = api.http.getMimeType("image.png");
// "image/png"
```
