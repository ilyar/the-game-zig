const std = @import("std");
const builtin = @import("builtin");

// Same Emscripten SDK version as the C template
const emsdk_version = "7.0.0";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const is_web = target.result.os.tag == .emscripten;

    // Default to size-optimized build for Web and Debug for desktop
    const optimize: std.builtin.Optimize = b.option(std.builtin.Optimize, "optimize", "Optimization mode") orelse
        if (is_web) .small else .debug;

    const run_step = b.step("run", "Build and run the game");

    if (is_web) return buildWeb(b, target, optimize, run_step);

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "game",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_dep.module("raylib") },
            },
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);
}

// raylib build.zig pins its own emsdk, so build raylib for Web here
fn buildWeb(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Optimize, run_step: *std.Build.Step) !void {
    const emsdk = b.lazyDependency("emsdk", .{}) orelse return;
    const raylib_src = b.dependency("raylib", .{});
    const is_windows = builtin.os.tag == .windows;

    // Install and activate the Emscripten SDK
    const emsdk_script = emsdk.path(if (is_windows) "emsdk.bat" else "emsdk");
    const install = b.addRunFile(emsdk_script);
    install.addArgs(&.{ "install", emsdk_version });
    const activate = b.addRunFile(emsdk_script);
    activate.addArgs(&.{ "activate", emsdk_version });
    activate.step.dependOn(&install.step);

    const sysroot = emsdk.path("upstream/emscripten/cache/sysroot/include");

    const raylib_lib = b.addLibrary(.{
        .name = "raylib",
        .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }),
    });
    raylib_lib.step.dependOn(&activate.step);
    raylib_lib.root_module.addCMacro("PLATFORM_WEB", "");
    raylib_lib.root_module.addCMacro("GRAPHICS_API_OPENGL_ES2", "");
    raylib_lib.root_module.addIncludePath(sysroot);
    raylib_lib.root_module.addIncludePath(raylib_src.path("src/external/glfw/include"));
    raylib_lib.root_module.addCSourceFiles(.{
        .root = raylib_src.path("src"),
        .files = &.{ "rcore.c", "rshapes.c", "rtextures.c", "rtext.c", "rmodels.c", "raudio.c" },
        .flags = &.{"-std=gnu99"},
    });

    const raylib_h = b.addTranslateC(.{
        .root_source_file = raylib_src.path("src/raylib.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    raylib_h.addIncludePath(sysroot);
    raylib_h.step.dependOn(&activate.step);

    const game = b.addLibrary(.{
        .name = "game",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_h.createModule() },
            },
        }),
    });
    game.root_module.addIncludePath(sysroot);

    // Link with emcc using the same flags as the C template
    const emcc = b.addRunFile(emsdk.path(if (is_windows) "upstream/emscripten/emcc.bat" else "upstream/emscripten/emcc"));
    emcc.addArg(switch (optimize) {
        .debug => "-g",
        .safe, .fast => "-O3",
        .small => "-Os",
    });
    // Zig builds C code with UBSan in Debug, link its runtime
    if (optimize == .debug) emcc.addArg("-fsanitize=undefined");
    emcc.addArgs(&.{ "-sUSE_GLFW=3", "-sASYNCIFY", "-sEXPORTED_RUNTIME_METHODS=ccall" });
    emcc.addArg("--shell-file");
    emcc.addFileArg(b.path("src/main.html"));
    emcc.addArtifactArg(game);
    emcc.addArtifactArg(raylib_lib);
    emcc.addArg("-o");
    const html = emcc.addOutputFileArg("index.html");

    const install_web = b.addInstallDirectory(.{
        .source_dir = html.dirname(),
        .install_dir = .{ .custom = "web" },
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&install_web.step);

    // Serve the web build locally and open it in the browser
    const emrun = b.addRunFile(emsdk.path(if (is_windows) "upstream/emscripten/emrun.bat" else "upstream/emscripten/emrun"));
    emrun.addFileArg(b.graph.path(.install_prefix, "web/index.html"));
    emrun.step.dependOn(&install_web.step);
    run_step.dependOn(&emrun.step);
}
