# Validation

Declarative input validation framework with chainable rules and comprehensive error reporting. Supports common validation patterns for strings, numbers, emails, and URLs.

## Import

```zig
const api = @import("api");
const Validator = api.Validator;
const validation = api.validation;
```

## Validator Functions

### isEmail

```zig
pub fn isEmail(email_str: []const u8) bool
```

Validates email format.

```zig
validation.isEmail("user@example.com")  // true
validation.isEmail("invalid")           // false
```

### isUrl

```zig
pub fn isUrl(url_str: []const u8) bool
```

Validates URL format.

```zig
validation.isUrl("https://example.com")  // true
validation.isUrl("ftp://example.com")    // false (http/https only)
```

### isNotEmpty

```zig
pub fn isNotEmpty(str: []const u8) bool
```

Checks if string is not empty/whitespace.

```zig
validation.isNotEmpty("hello")  // true
validation.isNotEmpty("")       // false
validation.isNotEmpty("   ")    // false
```

### isLengthBetween

```zig
pub fn isLengthBetween(str: []const u8, min: usize, max: usize) bool
```

Validates string length.

```zig
validation.isLengthBetween("hello", 1, 10)  // true
validation.isLengthBetween("hi", 5, 10)     // false
```

## Validator Builder

### Creating a Validator

```zig
const UserValidator = Validator(User);

var validator = UserValidator.init(allocator);
defer validator.deinit();
```

### Chaining Rules

```zig
_ = validator
    .required("name")
    .minLength("name", 2)
    .maxLength("name", 100)
    .email("email")
    .minValue("age", 18)
    .maxValue("age", 120);
```

### Validating

```zig
const result = validator.validate(user_input);

if (!result.valid) {
    for (result.errors) |err| {
        std.debug.print("{s}: {s}\n", .{err.field, err.message});
    }
}
```

## ValidationError

```zig
pub const ValidationError = struct {
    field: []const u8,
    message: []const u8,
    code: ErrorCode,
};

pub const ErrorCode = enum {
    required,
    min_length,
    max_length,
    min_value,
    max_value,
    pattern,
    email,
    url,
    custom,
};
```

## Handler Example

```zig
fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();

    if (body.len == 0) {
        return api.Response.err(.bad_request, "{\"error\":\"Body required\"}");
    }

    // Parse body
    const User = struct { email: []const u8 };
    const user = api.json.parse(User, ctx.allocator, body) catch {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid JSON\"}");
    };

    // Validate
    if (!api.validation.isEmail(user.email)) {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid email\"}");
    }

    return api.Response.jsonRaw("{\"created\":true}")
        .setStatus(.created);
}
```
