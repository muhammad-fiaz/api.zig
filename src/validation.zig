//! Input validation.
//! Chainable rules for strings, numbers, emails, URLs.

const std = @import("std");

/// Validation error details.
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
};

const RuleType = enum {
    required,
    min_length,
    max_length,
    min_value,
    max_value,
    email,
    url,
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
    };
}

/// Validates an email address format.
pub fn isEmail(email_str: []const u8) bool {
    var at_count: usize = 0;
    var at_pos: usize = 0;

    for (email_str, 0..) |c, i| {
        if (c == '@') {
            at_count += 1;
            at_pos = i;
        }
    }

    if (at_count != 1) return false;
    if (at_pos == 0 or at_pos == email_str.len - 1) return false;

    const domain = email_str[at_pos + 1 ..];
    var dot_found = false;
    for (domain) |c| {
        if (c == '.') dot_found = true;
    }

    return dot_found;
}

/// Validates a URL format.
pub fn isUrl(url_str: []const u8) bool {
    return std.mem.startsWith(u8, url_str, "http://") or
        std.mem.startsWith(u8, url_str, "https://");
}

/// Validates that a string is not empty.
pub fn isNotEmpty(str: []const u8) bool {
    return str.len > 0 and !std.mem.eql(u8, std.mem.trim(u8, str, " \t\n\r"), "");
}

/// Validates string length.
pub fn isLengthBetween(str: []const u8, min: usize, max: usize) bool {
    return str.len >= min and str.len <= max;
}

test "email validation" {
    try std.testing.expect(isEmail("test@example.com"));
    try std.testing.expect(!isEmail("invalid"));
    try std.testing.expect(!isEmail("@example.com"));
    try std.testing.expect(!isEmail("test@"));
}

test "url validation" {
    try std.testing.expect(isUrl("https://example.com"));
    try std.testing.expect(isUrl("http://localhost"));
    try std.testing.expect(!isUrl("ftp://example.com"));
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

    // Valid case
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

    // Invalid case
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
