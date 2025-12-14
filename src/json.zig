//! JSON utilities.
//! Parse, stringify, validate, and escape JSON data.

const std = @import("std");

/// JSON value type for dynamic parsing.
pub const Value = std.json.Value;

/// Parses a JSON string into the specified type.
/// Returns a Parsed(T) which contains the value and the arena allocator.
/// Caller must call .deinit() on the result.
pub fn parse(comptime T: type, allocator: std.mem.Allocator, input: []const u8) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, allocator, input, .{});
}

/// Parses a JSON string and returns a dynamic Value.
pub fn parseValue(allocator: std.mem.Allocator, input: []const u8) !std.json.Parsed(Value) {
    return std.json.parseFromSlice(Value, allocator, input, .{});
}

/// Stringifies a value to JSON.
pub fn stringify(allocator: std.mem.Allocator, value: anytype, options: std.json.Stringify.Options) ![]u8 {
    // Zig 0.15: use std.json.Stringify.valueAlloc for heap-allocated JSON output
    return std.json.Stringify.valueAlloc(allocator, value, options);
}

/// Stringifies a value to JSON with default options.
pub fn toJson(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    return stringify(allocator, value, .{});
}

/// Stringifies a value to JSON with pretty printing.
pub fn toPrettyJson(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    return stringify(allocator, value, .{ .whitespace = .indent_2 });
}

/// Checks if a string is valid JSON.
pub fn isValid(input: []const u8) bool {
    var scanner = std.json.Scanner.initCompleteInput(std.heap.page_allocator, input);
    defer scanner.deinit();
    while (true) {
        const token = scanner.next() catch return false;
        if (token == .end_of_document) return true;
    }
}

/// Escapes a string for JSON output.
pub fn escapeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var list = std.ArrayListUnmanaged(u8){};
    errdefer list.deinit(allocator);

    for (input) |c| {
        switch (c) {
            '"' => try list.appendSlice(allocator, "\\\""),
            '\\' => try list.appendSlice(allocator, "\\\\"),
            '\n' => try list.appendSlice(allocator, "\\n"),
            '\r' => try list.appendSlice(allocator, "\\r"),
            '\t' => try list.appendSlice(allocator, "\\t"),
            else => try list.append(allocator, c),
        }
    }

    return list.toOwnedSlice(allocator);
}

test "parse simple object" {
    const allocator = std.testing.allocator;
    const json_str = "{\"name\":\"test\"}";

    const TestType = struct { name: []const u8 };
    const result = try parse(TestType, allocator, json_str);
    defer result.deinit();

    try std.testing.expectEqualStrings("test", result.value.name);
}

test "stringify" {
    const allocator = std.testing.allocator;
    const value = .{ .name = "test", .count = @as(u32, 42) };

    const json_str = try stringify(allocator, value, .{});
    defer allocator.free(json_str);

    try std.testing.expect(json_str.len > 0);
}

test "isValid" {
    try std.testing.expect(isValid("{\"valid\":true}"));
    try std.testing.expect(!isValid("{invalid"));
}

test "escapeString" {
    const allocator = std.testing.allocator;
    const escaped = try escapeString(allocator, "hello\nworld");
    defer allocator.free(escaped);
    try std.testing.expectEqualStrings("hello\\nworld", escaped);
}
