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

HTTP request methods.

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

HTTP status codes.

```zig
pub const StatusCode = enum(u16) {
    @"continue" = 100,
    ok = 200,
    created = 201,
    no_content = 204,
    moved_permanently = 301,
    found = 302,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    internal_server_error = 500,
    // ... more
};
```

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
