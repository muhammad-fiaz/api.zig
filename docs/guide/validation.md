# Validation

api.zig provides utilities for validating request data.

## Built-in Validators

### Email Validation

```zig
const validation = @import("validation.zig");

if (validation.isEmail("user@example.com")) {
    // Valid email
}
```

### URL Validation

```zig
if (validation.isUrl("https://example.com")) {
    // Valid URL
}
```

### Not Empty

```zig
if (validation.isNotEmpty(user_input)) {
    // Input has content
}
```

### Length Validation

```zig
if (validation.isLengthBetween(password, 8, 128)) {
    // Password length is valid
}
```

## Validator Builder

Use the Validator type for declarative validation:

```zig
const Validator = api.Validator;

const UserInput = struct {
    name: []const u8,
    email: []const u8,
    age: u32,
};

fn validateUser(allocator: std.mem.Allocator, input: UserInput) !void {
    var validator = Validator(UserInput).init(allocator);
    defer validator.deinit();

    _ = validator
        .required("name")
        .minLength("name", 2)
        .maxLength("name", 100)
        .email("email")
        .minValue("age", 18)
        .maxValue("age", 120);

    const result = validator.validate(input);

    if (!result.valid) {
        // Handle validation errors
        for (result.errors) |err| {
            std.debug.print("Field: {s}, Error: {s}\n", .{err.field, err.message});
        }
    }
}
```

## Validation Error Codes

```zig
const ErrorCode = enum {
    required,       // Field is required
    min_length,     // String too short
    max_length,     // String too long
    min_value,      // Number too small
    max_value,      // Number too large
    pattern,        // Regex pattern mismatch
    email,          // Invalid email format
    url,            // Invalid URL format
    custom,         // Custom validation error
};
```

## Handler Example

```zig
fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();

    if (body.len == 0) {
        return api.Response.err(.bad_request, "{\"error\":\"Body is required\"}");
    }

    // Validate email format (simplified)
    if (!std.mem.containsAtLeast(u8, body, 1, "@")) {
        return api.Response.err(.bad_request, "{\"error\":\"Invalid email\"}");
    }

    return api.Response.jsonRaw("{\"created\":true}")
        .setStatus(.created);
}
```

## Custom Validation

Create custom validation logic:

```zig
fn validatePassword(password: []const u8) bool {
    if (password.len < 8) return false;

    var has_upper = false;
    var has_lower = false;
    var has_digit = false;

    for (password) |c| {
        if (c >= 'A' and c <= 'Z') has_upper = true;
        if (c >= 'a' and c <= 'z') has_lower = true;
        if (c >= '0' and c <= '9') has_digit = true;
    }

    return has_upper and has_lower and has_digit;
}
```

## Validation Response

Return structured validation errors:

```zig
fn createUser(ctx: *api.Context) api.Response {
    _ = ctx;

    // Validation failed example
    return api.Response.err(.bad_request,
        \\{"errors":[
        \\  {"field":"name","message":"Name is required"},
        \\  {"field":"email","message":"Invalid email format"}
        \\]}
    );
}
```
