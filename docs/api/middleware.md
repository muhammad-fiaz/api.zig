# Middleware

HTTP middleware components for request/response processing. Middleware executes in registration order and can short-circuit, modify requests, or post-process responses.

## Import

```zig
const api = @import("api");
const middleware = api.middleware;
```

## Standard Middleware

### Logger

Logs request and response details.

```zig
app.use(middleware.logger);
```

**Output:**

```
[REQ] GET /users
[RES] 200 (2ms)
```

### CORS

Handle Cross-Origin Resource Sharing.

```zig
const cors = middleware.cors(.{
    .allowed_origins = &.{ "https://example.com" },
    .allowed_methods = &.{ "GET", "POST", "OPTIONS" },
});

app.use(cors.handle);
```

### Request ID

Add `X-Request-ID` header to responses.

```zig
app.use(middleware.requestId);
```

### Recovery

Recover from panics (basic implementation).

```zig
app.use(middleware.recover);
```

## Custom Middleware

Create your own middleware:

```zig
fn myMiddleware(ctx: *api.Context, next: api.App.HandlerFn) api.Response {
    // Pre-processing
    std.debug.print("Before handler\n", .{});

    // Call next handler
    const response = next(ctx);

    // Post-processing
    std.debug.print("After handler\n", .{});

    return response;
}

app.use(myMiddleware);
```
