//! Build configuration for api.zig

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the api module
    const api_module = b.createModule(.{
        .root_source_file = b.path("src/api.zig"),
    });

    // Expose the module for external projects
    _ = b.addModule("api", .{
        .root_source_file = b.path("src/api.zig"),
    });

    // Main example (comprehensive example with all features)
    const main_example = b.addExecutable(.{
        .name = "api_zig_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    main_example.root_module.addImport("api", api_module);
    const install_main = b.addInstallArtifact(main_example, .{});

    // Run step
    const run_main = b.addRunArtifact(main_example);
    run_main.step.dependOn(&install_main.step);
    const run_step = b.step("run", "Run the API.Zig example");
    run_step.dependOn(&run_main.step);

    // Example step (alias)
    const example_step = b.step("example", "Run the API.Zig example");
    example_step.dependOn(&run_main.step);

    // GraphQL example
    const graphql_example = b.addExecutable(.{
        .name = "graphql_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/graphql.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    graphql_example.root_module.addImport("api", api_module);
    const install_graphql = b.addInstallArtifact(graphql_example, .{});

    // Run GraphQL example
    const run_graphql = b.addRunArtifact(graphql_example);
    run_graphql.step.dependOn(&install_graphql.step);
    const run_graphql_step = b.step("run-graphql", "Run the GraphQL example");
    run_graphql_step.dependOn(&run_graphql.step);

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Library
    const lib = b.addLibrary(.{
        .name = "api",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);
}
