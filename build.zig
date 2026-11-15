const std = @import("std");
const raylib = @import("raylib");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const is_web = target.result.os.tag == .emscripten;

    // Default to size-optimized build for Web and Debug for desktop
    const optimize: std.builtin.Optimize = b.option(std.builtin.Optimize, "optimize", "Optimization mode") orelse
        if (is_web) .small else .debug;

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    // Wait for raylib lazy dependencies (emsdk) to be fetched before configuring
    const raylib_mod = raylib_dep.builder.modules.get("raylib") orelse return;

    const game_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "raylib", .module = raylib_mod },
        },
    });

    const run_step = b.step("run", "Build and run the game");

    if (is_web) {
        // WebAssembly build: compile the game as a library and link it with emcc
        const wasm = b.addLibrary(.{
            .name = "game",
            .root_module = game_mod,
        });

        // Same emcc link flags as the C template
        var emcc_flags: raylib.emsdk.EmccFlags = .init(b.allocator);
        try emcc_flags.put(switch (optimize) {
            .debug => "-g",
            .safe, .fast => "-O3",
            .small => "-Os",
        }, {});
        try emcc_flags.put("-sASYNCIFY", {});
        // Zig builds C code with UBSan in Debug, link its runtime
        if (optimize == .debug) try emcc_flags.put("-fsanitize=undefined", {});
        var emcc_settings: raylib.emsdk.EmccSettings = .init(b.allocator);
        try emcc_settings.put("USE_GLFW", "3");
        try emcc_settings.put("EXPORTED_RUNTIME_METHODS", "ccall");

        const emcc_step = try raylib.emsdk.emccStep(b, &.{}, &.{ raylib_dep.artifact("raylib"), wasm }, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .shell_file_path = b.path("src/main.html"),
            .install_dir = .{ .custom = "web" },
            .out_file_name = "index.html",
        });
        b.getInstallStep().dependOn(emcc_step);

        // Serve the web build locally and open it in the browser
        const emrun_step = try raylib.emsdk.emrunStep(b, b.graph.path(.install_prefix, "web/index.html"), &.{});
        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else {
        const exe = b.addExecutable(.{
            .name = "game",
            .root_module = game_mod,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_step.dependOn(&run_cmd.step);
    }
}
