//! Error reporting and version utilities.
//! Internal error logging and update checking.

const std = @import("std");
const version_info = @import("version.zig");
const Logger = @import("logger.zig").Logger;

/// URL for reporting issues on GitHub.
pub const ISSUES_URL = "https://github.com/muhammad-fiaz/api.zig/issues";

/// GitHub repository owner.
const REPO_OWNER = "muhammad-fiaz";

/// GitHub repository name.
const REPO_NAME = "api.zig";

/// Current version of the library.
pub const CURRENT_VERSION: []const u8 = version_info.version;

/// Reports a library bug/runtime error with instructions for filing a bug report.
/// Use this for unexpected errors that indicate a bug in api.zig itself.
pub fn reportInternalError(message: []const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var logger = Logger.init(allocator) catch return;
    logger.errf("[API.ZIG ERROR] {s}", .{message}, null) catch {};
    logger.errf("If you believe this is a bug, please report it at: {s}", .{ISSUES_URL}, null) catch {};
}

/// Reports a library bug with an error value.
pub fn reportInternalErrorWithCode(err: anyerror) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var logger = Logger.init(allocator) catch return;
    logger.errf("[API.ZIG ERROR] {}", .{err}, null) catch {};
    logger.errf("If you believe this is a bug, please report it at: {s}", .{ISSUES_URL}, null) catch {};
}

/// Legacy aliases.
pub const reportError = reportInternalErrorWithCode;
pub const reportErrorMessage = reportInternalError;

/// Static flag to ensure update check runs only once per process.
var update_check_done = false;
var update_check_mutex = std.Thread.Mutex{};

/// Strips the 'v' or 'V' prefix from a version tag.
fn stripVersionPrefix(tag: []const u8) []const u8 {
    if (tag.len == 0) return tag;
    return if (tag[0] == 'v' or tag[0] == 'V') tag[1..] else tag;
}

/// Attempts to parse a semantic version string.
fn parseSemver(text: []const u8) ?std.SemanticVersion {
    return std.SemanticVersion.parse(text) catch null;
}

/// Represents the relationship between local and remote versions.
pub const VersionRelation = enum {
    local_newer,
    equal,
    remote_newer,
    unknown,
};

/// Compares the current version with the latest remote version.
pub fn compareVersions(latest_raw: []const u8) VersionRelation {
    const latest = stripVersionPrefix(latest_raw);
    const current = stripVersionPrefix(CURRENT_VERSION);

    if (parseSemver(current)) |cur| {
        if (parseSemver(latest)) |lat| {
            if (lat.major != cur.major) return if (lat.major > cur.major) .remote_newer else .local_newer;
            if (lat.minor != cur.minor) return if (lat.minor > cur.minor) .remote_newer else .local_newer;
            if (lat.patch != cur.patch) return if (lat.patch > cur.patch) .remote_newer else .local_newer;
            return .equal;
        }
    }

    if (std.mem.eql(u8, current, latest)) return .equal;
    return .unknown;
}

/// Update information structure.
pub const UpdateInfo = struct {
    latest_version: []const u8,
    current_version: []const u8,
    update_available: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *UpdateInfo) void {
        self.allocator.free(self.latest_version);
    }
};

/// Checks for updates in a background thread (runs only once per process).
/// Returns a thread handle so callers can optionally join during shutdown.
pub fn checkForUpdates(allocator: std.mem.Allocator) ?std.Thread {
    update_check_mutex.lock();
    defer update_check_mutex.unlock();

    if (update_check_done) return null;
    update_check_done = true;

    return std.Thread.spawn(.{}, checkWorker, .{allocator}) catch null;
}

/// Worker function that performs the actual update check.
fn checkWorker(allocator: std.mem.Allocator) void {
    _ = allocator;
    // Network request would go here
    // In production, this fetches from GitHub API
}

/// Returns the current library version.
pub fn getCurrentVersion() []const u8 {
    return CURRENT_VERSION;
}

/// Returns the GitHub issues URL.
pub fn getIssuesUrl() []const u8 {
    return ISSUES_URL;
}

/// Prints version information to stdout.
pub fn printVersionInfo() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var logger = Logger.init(allocator) catch return;
    logger.infof("{s} v{s}", .{ version_info.name, version_info.version }, null) catch {};
    logger.infof("Repository: {s}", .{version_info.repository}, null) catch {};
    logger.infof("Docs: {s}", .{version_info.docs_url}, null) catch {};
}

test "stripVersionPrefix" {
    try std.testing.expectEqualStrings("1.0.0", stripVersionPrefix("v1.0.0"));
    try std.testing.expectEqualStrings("1.0.0", stripVersionPrefix("V1.0.0"));
    try std.testing.expectEqualStrings("1.0.0", stripVersionPrefix("1.0.0"));
    try std.testing.expectEqualStrings("", stripVersionPrefix(""));
}

test "compareVersions equal" {
    const result = compareVersions(CURRENT_VERSION);
    try std.testing.expect(result == .equal);
}

test "getCurrentVersion" {
    try std.testing.expectEqualStrings(version_info.version, getCurrentVersion());
}

test "getIssuesUrl" {
    try std.testing.expect(ISSUES_URL.len > 0);
}

test "UpdateInfo deinit" {
    var info = UpdateInfo{
        .latest_version = try std.testing.allocator.dupe(u8, "1.0.0"),
        .current_version = "0.9.0",
        .update_available = true,
        .allocator = std.testing.allocator,
    };
    info.deinit();
}
