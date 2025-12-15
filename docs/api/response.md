# Response

HTTP response builder with fluent API for constructing responses. Supports JSON, HTML, text, redirects, and custom headers with chainable configuration methods.

## Import

```zig
const api = @import("api");
const Response = api.Response;
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | `StatusCode` | HTTP status code |
| `headers` | `HeaderList` | Response headers |
| `body` | `[]const u8` | Response body |
| `content_type` | `[]const u8` | Content-Type header |

## Constructor Summary

| Constructor | Content-Type | Description |
|-------------|-------------|-------------|
| `init()` | - | Empty response |
| `jsonRaw(str)` | `application/json` | Raw JSON string |
| `json(value)` | `application/json` | Serialize Zig value |
| `text(str)` | `text/plain; charset=utf-8` | Plain text |
| `html(str)` | `text/html; charset=utf-8` | HTML content |
| `xml(str)` | `application/xml` | XML content |
| `err(status, msg)` | `application/json` | Error with status |
| `redirect(url)` | - | 302 redirect |
| `permanentRedirect(url)` | - | 301 redirect |

## Builder Methods Summary

| Method | Description |
|--------|-------------|
| `.setStatus(status)` | Set HTTP status code |
| `.setHeader(name, value)` | Add response header |
| `.addHeader(name, value)` | Add additional header |
| `.setContentType(type)` | Override Content-Type |
| `.setBody(content)` | Set response body |
| `.withCors(origin)` | Add CORS headers |
| `.withCache(seconds)` | Set cache duration |
| `.withNoCache()` | Disable caching |

## Constructors

### init

```zig
pub fn init() Response
```

Creates an empty response.

### jsonRaw

```zig
pub fn jsonRaw(body_content: []const u8) Response
```

Creates a JSON response from a raw string.

### text

```zig
pub fn text(content: []const u8) Response
```

Creates a plain text response.

### html

```zig
pub fn html(content: []const u8) Response
```

Creates an HTML response.

### err

```zig
pub fn err(error_status: StatusCode, message: []const u8) Response
```

Creates an error response.

### redirect

```zig
pub fn redirect(location: []const u8) Response
```

Creates a temporary redirect (302).

### permanentRedirect

```zig
pub fn permanentRedirect(location: []const u8) Response
```

Creates a permanent redirect (301).

## Builder Methods

### setStatus

```zig
pub fn setStatus(self: Response, new_status: StatusCode) Response
```

Sets the HTTP status code.

### setHeader

```zig
pub fn setHeader(self: Response, name: []const u8, value: []const u8) Response
```

Adds a response header.

### setContentType

```zig
pub fn setContentType(self: Response, content_type_value: []const u8) Response
```

Sets the Content-Type header.

### setBody

```zig
pub fn setBody(self: Response, body_content: []const u8) Response
```

Sets the response body.

### withCors

```zig
pub fn withCors(self: Response, origin: []const u8) Response
```

Adds CORS headers.

### withCache

```zig
pub fn withCache(self: Response, max_age: u32) Response
```

Adds cache control headers.

### withNoCache

```zig
pub fn withNoCache(self: Response) Response
```

Adds no-cache headers.

## Helper Functions

```zig
pub fn ok(body_content: []const u8) Response
pub fn created(body_content: []const u8) Response
pub fn noContent() Response
pub fn badRequest(message: []const u8) Response
pub fn unauthorized(message: []const u8) Response
pub fn forbidden(message: []const u8) Response
pub fn notFound(message: []const u8) Response
pub fn internalError(message: []const u8) Response
```

## Examples

### JSON Response

```zig
api.Response.jsonRaw("{\"message\":\"Hello\"}")
```

### With Status Code

```zig
api.Response.jsonRaw("{\"id\":1}")
    .setStatus(.created)
```

### With Headers

```zig
api.Response.text("Hello")
    .setHeader("X-Custom", "value")
    .withCors("*")
```

### Error Response

```zig
api.Response.err(.not_found, "{\"error\":\"Not found\"}")
```
