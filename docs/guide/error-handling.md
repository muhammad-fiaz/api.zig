# Error Handling

Handle errors gracefully in api.zig applications.

## Error Response Methods

| Method | Status | Description |
|--------|--------|-------------|
| `Response.err(.bad_request, msg)` | 400 | Invalid input |
| `Response.err(.unauthorized, msg)` | 401 | Auth required |
| `Response.err(.forbidden, msg)` | 403 | Access denied |
| `Response.err(.not_found, msg)` | 404 | Not found |
| `Response.err(.method_not_allowed, msg)` | 405 | Wrong method |
| `Response.err(.conflict, msg)` | 409 | Conflict |
| `Response.err(.unprocessable_entity, msg)` | 422 | Validation failed |
| `Response.err(.too_many_requests, msg)` | 429 | Rate limited |
| `Response.err(.internal_server_error, msg)` | 500 | Server error |

## Error Responses

Return error responses with appropriate status codes:

```zig
fn notFound() api.Response {
    return api.Response.err(.not_found, "{\"error\":\"Resource not found\"}");
}

fn badRequest() api.Response {
    return api.Response.err(.bad_request, "{\"error\":\"Invalid input\"}");
}

fn unauthorized() api.Response {
    return api.Response.err(.unauthorized, "{\"error\":\"Authentication required\"}");
}

fn forbidden() api.Response {
    return api.Response.err(.forbidden, "{\"error\":\"Access denied\"}");
}

fn serverError() api.Response {
    return api.Response.err(.internal_server_error, "{\"error\":\"Internal server error\"}");
}
```

**Example Output:**

```json
{"error":"Resource not found"}
```

## Conditional Error Handling

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse {
        return api.Response.err(.bad_request, "{\"error\":\"Missing ID\"}");
    };

    const parsed_id = std.fmt.parseInt(u32, id, 10) catch {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid ID format\"}");
    };

    // Simulate user not found
    if (parsed_id > 100) {
        return api.Response.err(.not_found, "{\"error\":\"User not found\"}");
    }

    return api.Response.jsonRaw("{\"id\":1,\"name\":\"John\"}");
}
```

## Error Response Helper Functions

```zig
const response = @import("response.zig");

// Use helper functions
response.badRequest("{\"error\":\"msg\"}")
response.unauthorized("{\"error\":\"msg\"}")
response.forbidden("{\"error\":\"msg\"}")
response.notFound("{\"error\":\"msg\"}")
response.internalError("{\"error\":\"msg\"}")
```

## Custom Error Handler

Set a custom error handler for unhandled errors:

```zig
fn customErrorHandler(ctx: *api.Context, err: anyerror) api.Response {
    _ = ctx;
    std.debug.print("Error: {}\n", .{err});
    return api.Response.err(.internal_server_error, "{\"error\":\"Something went wrong\"}");
}

// Set the handler
app.setErrorHandler(customErrorHandler);
```

## Custom 404 Handler

```zig
fn custom404(ctx: *api.Context) api.Response {
    const path = ctx.path();
    _ = path;
    return api.Response.err(.not_found, "{\"error\":\"Route not found\",\"status\":404}");
}

// Set the handler
app.setNotFoundHandler(custom404);
```

## Reporting Library Bugs

If you encounter internal library errors:

```zig
const report = api.report;

// Report an error (for internal library issues only)
report.reportInternalError("Unexpected state in parser");

// Report with error code
report.reportInternalErrorWithCode(error.OutOfMemory);
```

## Error Status Codes

| Status                | Code | Use Case                         |
| --------------------- | ---- | -------------------------------- |
| Bad Request           | 400  | Invalid input, validation errors |
| Unauthorized          | 401  | Missing/invalid authentication   |
| Forbidden             | 403  | Authenticated but not authorized |
| Not Found             | 404  | Resource doesn't exist           |
| Method Not Allowed    | 405  | Wrong HTTP method                |
| Conflict              | 409  | Resource conflict                |
| Unprocessable Entity  | 422  | Semantic errors                  |
| Too Many Requests     | 429  | Rate limiting                    |
| Internal Server Error | 500  | Unexpected errors                |
| Service Unavailable   | 503  | Server overloaded                |

## Structured Error Format

Recommend consistent error format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Input validation failed",
    "details": [
      { "field": "email", "message": "Invalid email format" },
      { "field": "age", "message": "Must be at least 18" }
    ]
  }
}
```
