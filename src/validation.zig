//! Production-grade input validation with chainable rules and detailed error reporting.

const std = @import("std");

/// Validation error details with field, message, and error code.
pub const ValidationError = struct {
    field: []const u8,
    message: []const u8,
    code: ErrorCode,

    pub const ErrorCode = enum {
        required,
        min_length,
        max_length,
        min_value,
        max_value,
        pattern,
        email,
        url,
        uuid,
        alpha,
        alphanumeric,
        numeric,
        in_range,
        one_of,
        custom,
    };
};

/// Validation result containing errors if any.
pub const ValidationResult = struct {
    valid: bool,
    errors: []const ValidationError,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ValidationResult) void {
        self.allocator.free(self.errors);
    }

    pub fn firstError(self: ValidationResult) ?ValidationError {
        if (self.errors.len > 0) return self.errors[0];
        return null;
    }

    pub fn hasFieldError(self: ValidationResult, field: []const u8) bool {
        for (self.errors) |err| {
            if (std.mem.eql(u8, err.field, field)) return true;
        }
        return false;
    }
};

const RuleType = enum {
    required,
    min_length,
    max_length,
    min_value,
    max_value,
    email,
    url,
    uuid,
};

const Rule = struct {
    field: []const u8,
    type: RuleType,
    param_usize: usize = 0,
    param_int: i64 = 0,
    param_float: f64 = 0,
};

/// Validator with chainable rules.
pub fn Validator(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        rules: std.ArrayListUnmanaged(Rule) = .{},
        errors: std.ArrayListUnmanaged(ValidationError) = .{},

        const Self = @This();

        /// Creates a new validator.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Releases validator resources.
        pub fn deinit(self: *Self) void {
            self.rules.deinit(self.allocator);
            self.errors.deinit(self.allocator);
        }

        /// Validates a value against all rules.
        pub fn validate(self: *Self, value: T) ValidationResult {
            self.errors.clearRetainingCapacity();

            for (self.rules.items) |rule| {
                inline for (@typeInfo(T).@"struct".fields) |field_info| {
                    if (std.mem.eql(u8, field_info.name, rule.field)) {
                        const field_val = @field(value, field_info.name);
                        self.checkRule(rule, field_val, field_info.type);
                    }
                }
            }

            return ValidationResult{
                .valid = self.errors.items.len == 0,
                .errors = self.errors.toOwnedSlice(self.allocator) catch &.{},
                .allocator = self.allocator,
            };
        }

        fn checkRule(self: *Self, rule: Rule, value: anytype, comptime Type: type) void {
            switch (rule.type) {
                .required => {
                    if (@typeInfo(Type) == .optional) {
                        if (value == null) {
                            self.addError(rule.field, "Field is required", .required);
                        }
                    } else if (@typeInfo(Type) == .pointer) {
                        if (value.len == 0) {
                            self.addError(rule.field, "Field is required", .required);
                        }
                    }
                },
                .min_length => {
                    if (@typeInfo(Type) == .pointer and @typeInfo(Type).pointer.size == .slice) {
                        if (value.len < rule.param_usize) {
                            self.addError(rule.field, "Value is too short", .min_length);
                        }
                    }
                },
                .max_length => {
                    if (@typeInfo(Type) == .pointer and @typeInfo(Type).pointer.size == .slice) {
                        if (value.len > rule.param_usize) {
                            self.addError(rule.field, "Value is too long", .max_length);
                        }
                    }
                },
                .min_value => {
                    switch (@typeInfo(Type)) {
                        .int => if (value < rule.param_int) self.addError(rule.field, "Value is too small", .min_value),
                        .float => if (value < rule.param_float) self.addError(rule.field, "Value is too small", .min_value),
                        else => {},
                    }
                },
                .max_value => {
                    switch (@typeInfo(Type)) {
                        .int => if (value > rule.param_int) self.addError(rule.field, "Value is too large", .max_value),
                        .float => if (value > rule.param_float) self.addError(rule.field, "Value is too large", .max_value),
                        else => {},
                    }
                },
                .email => {
                    if (@typeInfo(Type) == .pointer) {
                        if (!isEmail(value)) {
                            self.addError(rule.field, "Invalid email format", .email);
                        }
                    }
                },
                .url => {
                    if (@typeInfo(Type) == .pointer) {
                        if (!isUrl(value)) {
                            self.addError(rule.field, "Invalid URL format", .url);
                        }
                    }
                },
                .uuid => {
                    if (@typeInfo(Type) == .pointer) {
                        if (!isUuid(value)) {
                            self.addError(rule.field, "Invalid UUID format", .custom);
                        }
                    }
                },
            }
        }

        fn addError(self: *Self, field: []const u8, msg: []const u8, code: ValidationError.ErrorCode) void {
            self.errors.append(self.allocator, .{
                .field = field,
                .message = msg,
                .code = code,
            }) catch {};
        }

        /// Adds a required field validation.
        pub fn required(self: *Self, field: []const u8) *Self {
            self.rules.append(self.allocator, .{ .field = field, .type = .required }) catch {};
            return self;
        }

        /// Adds a minimum length validation for strings.
        pub fn minLength(self: *Self, field: []const u8, min: usize) *Self {
            self.rules.append(self.allocator, .{ .field = field, .type = .min_length, .param_usize = min }) catch {};
            return self;
        }

        /// Adds a maximum length validation for strings.
        pub fn maxLength(self: *Self, field: []const u8, max: usize) *Self {
            self.rules.append(self.allocator, .{ .field = field, .type = .max_length, .param_usize = max }) catch {};
            return self;
        }

        /// Adds a minimum value validation for numbers.
        pub fn minValue(self: *Self, field: []const u8, min: anytype) *Self {
            const TMin = @TypeOf(min);
            var rule = Rule{ .field = field, .type = .min_value };
            if (@typeInfo(TMin) == .int or @typeInfo(TMin) == .comptime_int) {
                rule.param_int = @intCast(min);
            } else if (@typeInfo(TMin) == .float or @typeInfo(TMin) == .comptime_float) {
                rule.param_float = @floatCast(min);
            }
            self.rules.append(self.allocator, rule) catch {};
            return self;
        }

        /// Adds a maximum value validation for numbers.
        pub fn maxValue(self: *Self, field: []const u8, max: anytype) *Self {
            const TMax = @TypeOf(max);
            var rule = Rule{ .field = field, .type = .max_value };
            if (@typeInfo(TMax) == .int or @typeInfo(TMax) == .comptime_int) {
                rule.param_int = @intCast(max);
            } else if (@typeInfo(TMax) == .float or @typeInfo(TMax) == .comptime_float) {
                rule.param_float = @floatCast(max);
            }
            self.rules.append(self.allocator, rule) catch {};
            return self;
        }

        /// Adds an email format validation.
        pub fn email(self: *Self, field: []const u8) *Self {
            self.rules.append(self.allocator, .{ .field = field, .type = .email }) catch {};
            return self;
        }

        /// Adds a URL format validation.
        pub fn url(self: *Self, field: []const u8) *Self {
            self.rules.append(self.allocator, .{ .field = field, .type = .url }) catch {};
            return self;
        }

        /// Adds a UUID format validation.
        pub fn uuid(self: *Self, field: []const u8) *Self {
            self.rules.append(self.allocator, .{ .field = field, .type = .uuid }) catch {};
            return self;
        }
    };
}

/// Validates an email address format (RFC 5322 basic).
pub fn isEmail(email_str: []const u8) bool {
    if (email_str.len < 3 or email_str.len > 254) return false;

    var at_count: usize = 0;
    var at_pos: usize = 0;

    for (email_str, 0..) |c, i| {
        if (c == '@') {
            at_count += 1;
            at_pos = i;
        }
    }

    if (at_count != 1) return false;
    if (at_pos == 0 or at_pos >= email_str.len - 1) return false;

    const local = email_str[0..at_pos];
    const domain = email_str[at_pos + 1 ..];

    if (local.len == 0 or local.len > 64) return false;
    if (domain.len == 0 or domain.len > 253) return false;

    var dot_found = false;
    var last_was_dot = true;
    for (domain) |c| {
        if (c == '.') {
            if (last_was_dot) return false;
            dot_found = true;
            last_was_dot = true;
        } else {
            last_was_dot = false;
        }
    }

    return dot_found and !last_was_dot;
}

/// Validates a URL format (HTTP/HTTPS).
pub fn isUrl(url_str: []const u8) bool {
    if (!std.mem.startsWith(u8, url_str, "http://") and !std.mem.startsWith(u8, url_str, "https://")) {
        return false;
    }
    const after_scheme = if (std.mem.startsWith(u8, url_str, "https://"))
        url_str[8..]
    else
        url_str[7..];

    if (after_scheme.len == 0) return false;

    for (after_scheme) |c| {
        if (c == ' ' or c == '<' or c == '>') return false;
    }

    return true;
}

/// Validates a UUID string (RFC 4122 v1-v5).
pub fn isUuid(uuid_str: []const u8) bool {
    if (uuid_str.len != 36) return false;
    for (uuid_str, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else {
            if (!std.ascii.isHex(c)) return false;
        }
    }
    return true;
}

/// Validates that a string is not empty or whitespace-only.
pub fn isNotEmpty(str: []const u8) bool {
    return str.len > 0 and !std.mem.eql(u8, std.mem.trim(u8, str, " \t\n\r"), "");
}

/// Validates string length within bounds.
pub fn isLengthBetween(str: []const u8, min: usize, max: usize) bool {
    return str.len >= min and str.len <= max;
}

/// Validates alphabetic characters only.
pub fn isAlpha(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

/// Validates alphanumeric characters only.
pub fn isAlphanumeric(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!std.ascii.isAlphanumeric(c)) return false;
    }
    return true;
}

/// Validates numeric string (digits only).
pub fn isNumeric(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}

/// Validates hexadecimal string.
pub fn isHex(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

/// Validates ISO 8601 date format (YYYY-MM-DD).
pub fn isDate(str: []const u8) bool {
    if (str.len != 10) return false;
    if (str[4] != '-' or str[7] != '-') return false;

    const year = std.fmt.parseInt(u16, str[0..4], 10) catch return false;
    const month = std.fmt.parseInt(u8, str[5..7], 10) catch return false;
    const day = std.fmt.parseInt(u8, str[8..10], 10) catch return false;

    if (year < 1 or year > 9999) return false;
    if (month < 1 or month > 12) return false;
    if (day < 1 or day > 31) return false;

    return true;
}

/// Validates IPv4 address format.
pub fn isIpv4(str: []const u8) bool {
    var octets: u8 = 0;
    var current: u16 = 0;
    var digits: u8 = 0;

    for (str) |c| {
        if (c == '.') {
            if (digits == 0 or current > 255) return false;
            octets += 1;
            current = 0;
            digits = 0;
        } else if (std.ascii.isDigit(c)) {
            current = current * 10 + (c - '0');
            digits += 1;
            if (digits > 3) return false;
        } else {
            return false;
        }
    }

    return octets == 3 and digits > 0 and current <= 255;
}

/// Validates phone number format (basic international).
pub fn isPhone(str: []const u8) bool {
    if (str.len < 7 or str.len > 20) return false;

    var digit_count: usize = 0;
    for (str) |c| {
        if (std.ascii.isDigit(c)) {
            digit_count += 1;
        } else if (c != '+' and c != '-' and c != ' ' and c != '(' and c != ')') {
            return false;
        }
    }

    return digit_count >= 7 and digit_count <= 15;
}

/// Validates credit card number using Luhn algorithm.
pub fn isCreditCard(str: []const u8) bool {
    if (str.len < 13 or str.len > 19) return false;

    var sum: u32 = 0;
    var alternate = false;

    var i: usize = str.len;
    while (i > 0) {
        i -= 1;
        const c = str[i];
        if (!std.ascii.isDigit(c)) return false;

        var n: u32 = c - '0';
        if (alternate) {
            n *= 2;
            if (n > 9) n -= 9;
        }
        sum += n;
        alternate = !alternate;
    }

    return sum % 10 == 0;
}

/// Validates string matches one of the allowed values.
pub fn isOneOf(str: []const u8, allowed: []const []const u8) bool {
    for (allowed) |a| {
        if (std.mem.eql(u8, str, a)) return true;
    }
    return false;
}

/// Validates integer is in range.
pub fn inRange(comptime T: type, value: T, min: T, max: T) bool {
    return value >= min and value <= max;
}

test "email validation" {
    try std.testing.expect(isEmail("test@example.com"));
    try std.testing.expect(isEmail("user.name@domain.co.uk"));
    try std.testing.expect(!isEmail("invalid"));
    try std.testing.expect(!isEmail("@example.com"));
    try std.testing.expect(!isEmail("test@"));
    try std.testing.expect(!isEmail("test@.com"));
}

test "url validation" {
    try std.testing.expect(isUrl("https://example.com"));
    try std.testing.expect(isUrl("http://localhost:8080/path"));
    try std.testing.expect(!isUrl("ftp://example.com"));
    try std.testing.expect(!isUrl("https://"));
}

test "uuid validation" {
    try std.testing.expect(isUuid("123e4567-e89b-12d3-a456-426614174000"));
    try std.testing.expect(!isUuid("invalid-uuid"));
    try std.testing.expect(!isUuid("123e4567-e89b-12d3-a456"));
}

test "alpha validation" {
    try std.testing.expect(isAlpha("Hello"));
    try std.testing.expect(!isAlpha("Hello123"));
    try std.testing.expect(!isAlpha(""));
}

test "alphanumeric validation" {
    try std.testing.expect(isAlphanumeric("Hello123"));
    try std.testing.expect(!isAlphanumeric("Hello 123"));
}

test "date validation" {
    try std.testing.expect(isDate("2024-01-15"));
    try std.testing.expect(!isDate("2024/01/15"));
    try std.testing.expect(!isDate("01-15-2024"));
}

test "ipv4 validation" {
    try std.testing.expect(isIpv4("192.168.1.1"));
    try std.testing.expect(isIpv4("0.0.0.0"));
    try std.testing.expect(!isIpv4("256.1.1.1"));
    try std.testing.expect(!isIpv4("192.168.1"));
}

test "credit card validation" {
    try std.testing.expect(isCreditCard("4111111111111111"));
    try std.testing.expect(!isCreditCard("1234567890123456"));
}

test "not empty validation" {
    try std.testing.expect(isNotEmpty("hello"));
    try std.testing.expect(!isNotEmpty(""));
    try std.testing.expect(!isNotEmpty("   "));
}

test "length validation" {
    try std.testing.expect(isLengthBetween("hello", 1, 10));
    try std.testing.expect(!isLengthBetween("hi", 3, 10));
}

test "Validator struct" {
    const TestStruct = struct {
        name: []const u8,
        age: i32,
        email: []const u8,
    };

    var validator = Validator(TestStruct).init(std.testing.allocator);
    defer validator.deinit();

    _ = validator.required("name")
        .minLength("name", 3)
        .minValue("age", 18)
        .email("email");

    {
        const data = TestStruct{
            .name = "John",
            .age = 25,
            .email = "john@example.com",
        };
        var result = validator.validate(data);
        defer result.deinit();
        try std.testing.expect(result.valid);
        try std.testing.expectEqual(@as(usize, 0), result.errors.len);
    }

    {
        const data = TestStruct{
            .name = "Jo",
            .age = 16,
            .email = "invalid-email",
        };
        var result = validator.validate(data);
        defer result.deinit();
        try std.testing.expect(!result.valid);
        try std.testing.expect(result.errors.len >= 3);
    }
}
