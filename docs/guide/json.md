# JSON

api.zig includes JSON utilities for parsing and serialization.

## JSON Methods

| Method | Description |
|--------|-------------|
| `json.parse(T, allocator, str)` | Parse JSON string to struct |
| `json.parseValue(allocator, str)` | Parse to dynamic value |
| `json.stringify(allocator, value, opts)` | Serialize to JSON string |
| `json.toPrettyJson(allocator, value)` | Serialize with formatting |
| `json.isValid(str)` | Check if string is valid JSON |
| `json.escapeString(allocator, str)` | Escape special characters |

## Parsing JSON

### Parse into Type

```zig
const json = api.json;

const User = struct {
    id: u32,
    name: []const u8,
    active: bool,
};

const json_str = "{\"id\":1,\"name\":\"John\",\"active\":true}";
const user = try json.parse(User, allocator, json_str);

// user.id = 1
// user.name = "John"
// user.active = true
```

**Input:**

```json
{"id":1,"name":"John","active":true}
```

**Result:** `User{ .id = 1, .name = "John", .active = true }`

### Parse Dynamic JSON

```zig
const parsed = try json.parseValue(allocator, json_str);
defer parsed.deinit();

// Access values
const id = parsed.value.object.get("id").?.integer;
```

## Serializing to JSON

### Stringify

```zig
const user = User{
    .id = 1,
    .name = "John",
    .active = true,
};

const json_str = try json.stringify(allocator, user, .{});
defer allocator.free(json_str);
// {"id":1,"name":"John","active":true}
```

### Pretty Print

```zig
const json_str = try json.toPrettyJson(allocator, user);
defer allocator.free(json_str);
// {
//   "id": 1,
//   "name": "John",
//   "active": true
// }
```

## Validation

### Check Valid JSON

```zig
if (json.isValid("{\"valid\":true}")) {
    // Valid JSON
}

if (!json.isValid("{invalid")) {
    // Invalid JSON
}
```

## Escaping Strings

```zig
const escaped = try json.escapeString(allocator, "hello\nworld");
defer allocator.free(escaped);
// hello\\nworld
```

## Handler Example

```zig
fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();

    // Validate JSON format
    if (!api.json.isValid(body)) {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid JSON\"}");
    }

    // Process the request...
    return api.Response.jsonRaw("{\"created\":true}")
        .setStatus(.created);
}
```

## JSON Response Helpers

### Raw JSON String

```zig
// For pre-formatted JSON strings
api.Response.jsonRaw("{\"message\":\"Hello\"}")
```

### Building JSON Manually

```zig
fn handler(ctx: *api.Context) api.Response {
    _ = ctx;

    // For simple responses, use raw JSON
    return api.Response.jsonRaw("{\"status\":\"ok\",\"timestamp\":1234567890}");
}
```

## Error Handling

```zig
fn parseBody(ctx: *api.Context) api.Response {
    const body = ctx.body();

    const User = struct { name: []const u8 };

    const user = api.json.parse(User, ctx.allocator, body) catch {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid JSON body\"}");
    };

    _ = user;
    return api.Response.jsonRaw("{\"ok\":true}");
}
```
