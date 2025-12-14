# JSON

JSON parsing and serialization utilities.

## Import

```zig
const api = @import("api");
const json = api.json;
```

## Functions

### parse

```zig
pub fn parse(comptime T: type, allocator: Allocator, input: []const u8) !T
```

Parses JSON into a typed struct.

```zig
const User = struct {
    id: u32,
    name: []const u8,
};

const user = try json.parse(User, allocator, "{\"id\":1,\"name\":\"John\"}");
// user.id = 1
// user.name = "John"
```

### parseValue

```zig
pub fn parseValue(allocator: Allocator, input: []const u8) !std.json.Parsed(Value)
```

Parses JSON into a dynamic Value.

```zig
const parsed = try json.parseValue(allocator, input);
defer parsed.deinit();

const id = parsed.value.object.get("id").?.integer;
```

### stringify

```zig
pub fn stringify(allocator: Allocator, value: anytype, options: StringifyOptions) ![]u8
```

Converts a value to JSON.

```zig
const user = .{ .id = 1, .name = "John" };
const str = try json.stringify(allocator, user, .{});
defer allocator.free(str);
// {"id":1,"name":"John"}
```

### toJson

```zig
pub fn toJson(allocator: Allocator, value: anytype) ![]u8
```

Stringifies with default options.

### toPrettyJson

```zig
pub fn toPrettyJson(allocator: Allocator, value: anytype) ![]u8
```

Stringifies with pretty printing.

```zig
const str = try json.toPrettyJson(allocator, user);
// {
//   "id": 1,
//   "name": "John"
// }
```

### isValid

```zig
pub fn isValid(input: []const u8) bool
```

Checks if a string is valid JSON.

```zig
json.isValid("{\"valid\":true}")  // true
json.isValid("{invalid")          // false
```

### escapeString

```zig
pub fn escapeString(allocator: Allocator, input: []const u8) ![]u8
```

Escapes a string for JSON.

```zig
const escaped = try json.escapeString(allocator, "hello\nworld");
// "hello\\nworld"
```

## Example

```zig
fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();

    if (!api.json.isValid(body)) {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid JSON\"}");
    }

    const User = struct { name: []const u8 };
    const user = api.json.parse(User, ctx.allocator, body) catch {
        return api.Response.err(.bad_request, "{\"error\":\"Parse error\"}");
    };

    _ = user;
    return api.Response.jsonRaw("{\"created\":true}")
        .setStatus(.created);
}
```
