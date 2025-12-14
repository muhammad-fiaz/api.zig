# Extractors

Type-safe request data extraction with compile-time validation. Extractors parse and validate request data into strongly-typed Zig structs.

## Import

```zig
const api = @import("api");
const Path = api.Path;
const Query = api.Query;
const Body = api.Body;
const Header = api.Header;
```

## Path

Extracts path parameters into a struct.

```zig
const PathParams = Path(struct {
    id: u32,
    name: []const u8,
});

fn handler(ctx: *api.Context) api.Response {
    const params = PathParams.extract(ctx) catch {
        return api.Response.err(.bad_request, "{}");
    };

    _ = params.value.id;    // u32
    _ = params.value.name;  // []const u8

    return api.Response.jsonRaw("{}");
}
```

## Query

Extracts query parameters into a struct.

```zig
const QueryParams = Query(struct {
    page: u32 = 1,     // With default
    limit: u32 = 10,
    search: ?[]const u8 = null,  // Optional
});

fn handler(ctx: *api.Context) api.Response {
    const query = QueryParams.extract(ctx) catch {
        return api.Response.err(.bad_request, "{}");
    };

    _ = query.value.page;   // u32
    _ = query.value.limit;  // u32
    _ = query.value.search; // ?[]const u8

    return api.Response.jsonRaw("{}");
}
```

## Body

Extracts and parses JSON request body.

```zig
const CreateUserBody = Body(struct {
    name: []const u8,
    email: []const u8,
    age: u32,
});

fn createUser(ctx: *api.Context) api.Response {
    const body = CreateUserBody.extract(ctx) catch {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid body\"}");
    };

    _ = body.value.name;
    _ = body.value.email;
    _ = body.value.age;

    return api.Response.jsonRaw("{\"created\":true}")
        .setStatus(.created);
}
```

## Header

Extracts a specific header.

```zig
const AuthHeader = Header("Authorization");
const ContentTypeHeader = Header("Content-Type");

fn handler(ctx: *api.Context) api.Response {
    const auth = AuthHeader.extract(ctx) catch {
        return api.Response.err(.unauthorized, "{}");
    };

    _ = auth.value;  // Header value

    return api.Response.jsonRaw("{}");
}
```

## Built-in Header Extractors

```zig
const Authorization = api.extractors.Authorization;
const ContentType = api.extractors.ContentType;
const UserAgent = api.extractors.UserAgent;
```

## Supported Types

Path and Query extractors support:

| Type      | Example               |
| --------- | --------------------- |
| Integers  | `u32`, `i64`, etc.    |
| Floats    | `f32`, `f64`          |
| Booleans  | `bool`                |
| Strings   | `[]const u8`          |
| Optionals | `?u32`, `?[]const u8` |

## Example

```zig
const PathParams = Path(struct { id: u32 });
const QueryParams = Query(struct { include_deleted: bool = false });
const CreateBody = Body(struct { name: []const u8 });

fn updateUser(ctx: *api.Context) api.Response {
    const path = PathParams.extract(ctx) catch return api.Response.err(.bad_request, "{}");
    const query = QueryParams.extract(ctx) catch return api.Response.err(.bad_request, "{}");
    const body = CreateBody.extract(ctx) catch return api.Response.err(.bad_request, "{}");

    _ = path.value.id;
    _ = query.value.include_deleted;
    _ = body.value.name;

    return api.Response.jsonRaw("{\"updated\":true}");
}
```
