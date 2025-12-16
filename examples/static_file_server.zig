const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Static File Server",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Serve static files from "public" directory at root
    try app.serveStatic("/", "public");

    // Serve assets from "assets" directory at /assets
    try app.serveStatic("/assets", "assets");

    // API routes work alongside static files
    try app.get("/api/status", status);

    try app.run(.{ .port = 8000 });
}

fn status(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.json(.{ .status = "ok" });
}
