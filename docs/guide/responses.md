# Responses

api.zig provides a fluent Response builder for constructing HTTP responses.

## Response Methods

| Method | Content-Type | Description |
|--------|-------------|-------------|
| `Response.jsonRaw()` | `application/json` | Raw JSON string |
| `Response.json()` | `application/json` | Serialize Zig struct |
| `Response.text()` | `text/plain; charset=utf-8` | Plain text |
| `Response.html()` | `text/html; charset=utf-8` | HTML content |
| `Response.xml()` | `application/xml` | XML content |
| `Response.err()` | `application/json` | Error with status |
| `Response.redirect()` | - | 302 redirect |
| `Response.permanentRedirect()` | - | 301 redirect |
| `Response.init()` | - | Empty response |

## Response Types

### JSON Response

```zig
// Raw JSON string
api.Response.jsonRaw("{\"message\":\"Hello\"}")

// With status code
api.Response.jsonRaw("{\"id\":1}")
    .setStatus(.created)
```

**Output:**

```json
{"message":"Hello"}
```

### Text Response

```zig
api.Response.text("Hello, World!")
```

### HTML Response

```zig
api.Response.html("<h1>Welcome</h1>")
```

### Error Response

```zig
api.Response.err(.not_found, "{\"error\":\"Not found\"}")
api.Response.err(.bad_request, "{\"error\":\"Invalid input\"}")
api.Response.err(.internal_server_error, "{\"error\":\"Server error\"}")
```

### Redirect Response

```zig
// Temporary redirect (302)
api.Response.redirect("/new-location")

// Permanent redirect (301)
api.Response.permanentRedirect("/new-location")
```

## Builder Pattern Methods

| Method | Description |
|--------|-------------|
| `.setStatus(status)` | Set HTTP status code |
| `.setContentType(type)` | Override Content-Type header |
| `.setHeader(name, value)` | Add custom header |
| `.addHeader(name, value)` | Add additional header |
| `.withCors(origin)` | Add CORS headers |
| `.withCache(seconds)` | Set cache duration |
| `.withNoCache()` | Disable caching |

Chain methods to customize responses:

```zig
api.Response.text("Created")
    .setStatus(.created)
    .setHeader("X-Custom-Header", "value")
    .setContentType("text/plain")
```

## Setting Status Codes

| Code | Constant | Description |
|------|----------|-------------|
| 200 | `.ok` | Success |
| 201 | `.created` | Resource created |
| 204 | `.no_content` | Success, no body |
| 301 | `.moved_permanently` | Permanent redirect |
| 302 | `.found` | Temporary redirect |
| 400 | `.bad_request` | Invalid request |
| 401 | `.unauthorized` | Auth required |
| 403 | `.forbidden` | Access denied |
| 404 | `.not_found` | Not found |
| 422 | `.unprocessable_entity` | Validation failed |
| 429 | `.too_many_requests` | Rate limited |
| 500 | `.internal_server_error` | Server error |

```zig
.setStatus(.ok)              // 200
.setStatus(.created)         // 201
.setStatus(.no_content)      // 204
.setStatus(.bad_request)     // 400
.setStatus(.unauthorized)    // 401
.setStatus(.forbidden)       // 403
.setStatus(.not_found)       // 404
.setStatus(.internal_server_error) // 500
```

## Custom Headers

```zig
api.Response.text("Hello")
    .setHeader("X-Request-Id", "abc123")
    .setHeader("X-Trace-Id", "xyz789")
```

## CORS Headers

```zig
api.Response.jsonRaw("{}")
    .withCors("*")  // Allow all origins

api.Response.jsonRaw("{}")
    .withCors("https://example.com")  // Specific origin
```

## Cache Control

```zig
// Enable caching
api.Response.text("cached")
    .withCache(3600)  // 1 hour

// Disable caching
api.Response.text("no-cache")
    .withNoCache()
```

## Empty Response

```zig
// 204 No Content
api.Response.init().setStatus(.no_content)
```

## Helper Functions

```zig
const response = @import("response.zig");

response.ok("Success")              // 200 OK
response.created("Created")         // 201 Created
response.noContent()                // 204 No Content
response.badRequest("Invalid")      // 400 Bad Request
response.unauthorized("Auth needed") // 401 Unauthorized
response.forbidden("Access denied")  // 403 Forbidden
response.notFound("Not found")      // 404 Not Found
response.internalError("Error")     // 500 Server Error
```

## Complete Example

```zig
fn createUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw("{\"id\":1,\"message\":\"User created\"}")
        .setStatus(.created)
        .setHeader("Location", "/users/1")
        .withCors("*");
}
```
