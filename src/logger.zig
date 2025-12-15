//! Thread-safe structured logging with ANSI color support across Windows, Linux, and macOS.

const std = @import("std");
const builtin = @import("builtin");

/// Enable Windows virtual terminal processing for ANSI colors
fn enableWindowsAnsiSupport() void {
    if (builtin.os.tag == .windows) {
        const kernel32 = std.os.windows.kernel32;
        // Enable for both stdout and stderr
        inline for ([_]std.os.windows.DWORD{ std.os.windows.STD_OUTPUT_HANDLE, std.os.windows.STD_ERROR_HANDLE }) |handle_type| {
            const handle = kernel32.GetStdHandle(handle_type);
            if (handle != std.os.windows.INVALID_HANDLE_VALUE and handle != null) {
                var mode: std.os.windows.DWORD = 0;
                if (kernel32.GetConsoleMode(handle.?, &mode) != 0) {
                    // ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                    mode |= 0x0004;
                    _ = kernel32.SetConsoleMode(handle.?, mode);
                }
            }
        }
    }
}

/// ANSI color codes for cross-platform terminal coloring.
pub const Color = struct {
    pub const reset = "\x1b[0m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";

    // Bright colors
    pub const bright_red = "\x1b[91m";
    pub const bright_green = "\x1b[92m";
    pub const bright_yellow = "\x1b[93m";
    pub const bright_blue = "\x1b[94m";
    pub const bright_magenta = "\x1b[95m";
    pub const bright_cyan = "\x1b[96m";
};

/// Log level.
pub const Level = enum {
    debug,
    info,
    warn,
    err,

    pub fn toString(self: Level) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }

    pub fn color(self: Level) []const u8 {
        return switch (self) {
            .debug => Color.cyan,
            .info => Color.green,
            .warn => Color.yellow,
            .err => Color.red,
        };
    }
};

/// Cross-platform colorful logger for API.Zig framework.
/// Thread-safe and automatically enables ANSI color support on Windows terminals.
pub const Logger = struct {
    allocator: std.mem.Allocator,
    level: Level = .info,
    colors_enabled: bool = true,
    mutex: std.Thread.Mutex = .{},

    var ansi_initialized: bool = false;
    var init_mutex: std.Thread.Mutex = .{};

    /// Creates a new logger with Windows ANSI support enabled.
    pub fn init(allocator: std.mem.Allocator) !*Logger {
        // Thread-safe initialization of Windows ANSI colors
        init_mutex.lock();
        defer init_mutex.unlock();

        if (!ansi_initialized) {
            enableWindowsAnsiSupport();
            ansi_initialized = true;
        }

        const self = try allocator.create(Logger);
        self.* = .{
            .allocator = allocator,
            .mutex = .{},
        };
        return self;
    }

    /// Releases logger resources.
    pub fn deinit(self: *Logger) void {
        self.allocator.destroy(self);
    }

    /// Set the minimum log level.
    pub fn setLevel(self: *Logger, level: Level) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.level = level;
    }

    /// Enable or disable colored output.
    pub fn setColors(self: *Logger, enabled: bool) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.colors_enabled = enabled;
    }

    /// Thread-safe logging helper using std.debug.print (thread-safe in Zig)
    fn logMessage(self: *Logger, comptime color: []const u8, comptime label: []const u8, comptime fmt: []const u8, args: anytype) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.colors_enabled) {
            std.debug.print(color ++ label ++ Color.reset ++ " " ++ fmt ++ "\n", args);
        } else {
            std.debug.print(label ++ " " ++ fmt ++ "\n", args);
        }
    }

    /// Logs a debug message.
    pub fn debug(self: *Logger, msg: []const u8, extra: anytype) !void {
        _ = extra;
        if (@intFromEnum(self.level) <= @intFromEnum(Level.debug)) {
            self.logMessage(Color.cyan, "[DEBUG]", "{s}", .{msg});
        }
    }

    /// Logs a debug message with format args.
    pub fn debugf(self: *Logger, comptime fmt: []const u8, args: anytype, extra: anytype) !void {
        _ = extra;
        if (@intFromEnum(self.level) <= @intFromEnum(Level.debug)) {
            self.logMessage(Color.cyan, "[DEBUG]", fmt, args);
        }
    }

    /// Logs an info message.
    pub fn info(self: *Logger, msg: []const u8, extra: anytype) !void {
        _ = extra;
        if (@intFromEnum(self.level) <= @intFromEnum(Level.info)) {
            self.logMessage(Color.green, "[INFO]", "{s}", .{msg});
        }
    }

    /// Logs an info message with format args.
    pub fn infof(self: *Logger, comptime fmt: []const u8, args: anytype, extra: anytype) !void {
        _ = extra;
        if (@intFromEnum(self.level) <= @intFromEnum(Level.info)) {
            self.logMessage(Color.green, "[INFO]", fmt, args);
        }
    }

    /// Logs a warning message.
    pub fn warn(self: *Logger, msg: []const u8, extra: anytype) !void {
        _ = extra;
        if (@intFromEnum(self.level) <= @intFromEnum(Level.warn)) {
            self.logMessage(Color.yellow, "[WARN]", "{s}", .{msg});
        }
    }

    /// Logs a warning message with format args.
    pub fn warnf(self: *Logger, comptime fmt: []const u8, args: anytype, extra: anytype) !void {
        _ = extra;
        if (@intFromEnum(self.level) <= @intFromEnum(Level.warn)) {
            self.logMessage(Color.yellow, "[WARN]", fmt, args);
        }
    }

    /// Logs an error message.
    pub fn err(self: *Logger, msg: []const u8, extra: anytype) !void {
        _ = extra;
        self.logMessage(Color.red, "[ERROR]", "{s}", .{msg});
    }

    /// Logs an error message with format args.
    pub fn errf(self: *Logger, comptime fmt: []const u8, args: anytype, extra: anytype) !void {
        _ = extra;
        self.logMessage(Color.red, "[ERROR]", fmt, args);
    }

    /// Logs a success message.
    pub fn success(self: *Logger, msg: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.colors_enabled) {
            std.debug.print(Color.green ++ Color.bold ++ "[OK]" ++ Color.reset ++ " {s}\n", .{msg});
        } else {
            std.debug.print("[OK] {s}\n", .{msg});
        }
    }
};

test "logger init and deinit" {
    const logger = try Logger.init(std.testing.allocator);
    defer logger.deinit();
    // try logger.info("test message", null);
}

test "logger levels" {
    const logger = try Logger.init(std.testing.allocator);
    defer logger.deinit();
    // try logger.debug("debug", null);
    // try logger.info("info", null);
    // try logger.warn("warn", null);
    // try logger.err("error", null); // Uncomment to test error logging (prints to stderr)
}
