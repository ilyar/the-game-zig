const std = @import("std");
const raylib = @import("raylib");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    if (target.result.os.tag == .emscripten) {
        // WebAssembly build: compile the game as a library and link it with emcc
        const wasm = b.addLibrary(.{
            .name = "game",
            .root_module = game_mod,
        });

        const emcc_step = try raylib.emsdk.emccStep(b, &.{}, &.{ raylib_dep.artifact("raylib"), wasm }, .{
            .optimize = optimize,
            .flags = raylib.emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize }),
            .settings = raylib.emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize }),
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
