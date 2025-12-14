//! Library version info.
//! Version constants and repository URLs.

/// Current library version.
pub const version = "0.0.1";

/// Library name.
pub const name = "api.zig";

/// GitHub repository URL.
pub const repository = "https://github.com/muhammad-fiaz/api.zig";

/// Documentation URL.
pub const docs_url = "https://muhammad-fiaz.github.io/api.zig/";

/// Returns the full version string with name.
pub fn getFullVersion() []const u8 {
    return name ++ " v" ++ version;
}

/// Returns the repository URL.
pub fn getRepository() []const u8 {
    return repository;
}
