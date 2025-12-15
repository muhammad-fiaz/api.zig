# HTTP

Core HTTP/1.1 protocol types following RFC 7231. Provides method enumeration, status codes with reason phrases, header management, and MIME type detection.

## Import

```zig
const api = @import("api");
const http = api.http;
const Method = api.Method;
const StatusCode = api.StatusCode;
```

## Method

HTTP request methods supported by api.zig:

| Method | Constant | Description |
|--------|----------|-------------|
| GET | `.GET` | Retrieve resources |
| POST | `.POST` | Create resources |
| PUT | `.PUT` | Replace resources |
| DELETE | `.DELETE` | Remove resources |
| PATCH | `.PATCH` | Partial update |
| HEAD | `.HEAD` | Headers only |
| OPTIONS | `.OPTIONS` | CORS preflight |
| TRACE | `.TRACE` | Debug/diagnostic |
| CONNECT | `.CONNECT` | Tunnel connection |

```zig
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
    TRACE,
    CONNECT,
};
```

### Methods

#### fromString

```zig
pub fn fromString(str: []const u8) ?Method
```

Parses a string into a Method.

#### toString

```zig
pub fn toString(self: Method) []const u8
```

Returns the string representation.

## StatusCode

HTTP status codes organized by category:

### Informational (1xx)

| Code | Constant | Phrase |
|------|----------|--------|
| 100 | `.@"continue"` | Continue |
| 101 | `.switching_protocols` | Switching Protocols |

### Success (2xx)

| Code | Constant | Phrase |
|------|----------|--------|
| 200 | `.ok` | OK |
| 201 | `.created` | Created |
| 202 | `.accepted` | Accepted |
| 204 | `.no_content` | No Content |

### Redirection (3xx)

| Code | Constant | Phrase |
|------|----------|--------|
| 301 | `.moved_permanently` | Moved Permanently |
| 302 | `.found` | Found |
| 304 | `.not_modified` | Not Modified |
| 307 | `.temporary_redirect` | Temporary Redirect |
| 308 | `.permanent_redirect` | Permanent Redirect |

### Client Error (4xx)

| Code | Constant | Phrase |
|------|----------|--------|
| 400 | `.bad_request` | Bad Request |
| 401 | `.unauthorized` | Unauthorized |
| 403 | `.forbidden` | Forbidden |
| 404 | `.not_found` | Not Found |
| 405 | `.method_not_allowed` | Method Not Allowed |
| 409 | `.conflict` | Conflict |
| 422 | `.unprocessable_entity` | Unprocessable Entity |
| 429 | `.too_many_requests` | Too Many Requests |

### Server Error (5xx)

| Code | Constant | Phrase |
|------|----------|--------|
| 500 | `.internal_server_error` | Internal Server Error |
| 502 | `.bad_gateway` | Bad Gateway |
| 503 | `.service_unavailable` | Service Unavailable |
| 504 | `.gateway_timeout` | Gateway Timeout |

### Methods

#### toInt

```zig
pub fn toInt(self: StatusCode) u16
```

Returns the numeric value.

#### phrase

```zig
pub fn phrase(self: StatusCode) []const u8
```

Returns the reason phrase.

#### isSuccess

```zig
pub fn isSuccess(self: StatusCode) bool
```

Returns true for 2xx codes.

#### isRedirect

```zig
pub fn isRedirect(self: StatusCode) bool
```

Returns true for 3xx codes.

#### isClientError

```zig
pub fn isClientError(self: StatusCode) bool
```

Returns true for 4xx codes.

#### isServerError

```zig
pub fn isServerError(self: StatusCode) bool
```

Returns true for 5xx codes.

## ContentTypes

Common MIME types.

```zig
const ContentTypes = http.Headers.ContentTypes;

ContentTypes.json        // "application/json"
ContentTypes.html        // "text/html; charset=utf-8"
ContentTypes.plain       // "text/plain; charset=utf-8"
ContentTypes.xml         // "application/xml"
ContentTypes.form        // "application/x-www-form-urlencoded"
ContentTypes.css         // "text/css"
ContentTypes.javascript  // "application/javascript"
ContentTypes.png         // "image/png"
ContentTypes.jpeg        // "image/jpeg"
```

## getMimeType

```zig
pub fn getMimeType(path_str: []const u8) []const u8
```

Determines MIME type from file extension.

```zig
http.getMimeType("style.css")   // "text/css"
http.getMimeType("data.json")   // "application/json"
http.getMimeType("image.png")   // "image/png"
```

## Example

```zig
fn handler(ctx: *api.Context) api.Response {
    const method = ctx.method();

    if (method == .POST) {
        return api.Response.jsonRaw("{}")
            .setStatus(.created);
    }

    return api.Response.text(method.toString());
}
```
