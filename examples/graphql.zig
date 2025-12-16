const std = @import("std");
const server = @import("graphql_server.zig");

pub fn main() !void {
    try server.main();
}
