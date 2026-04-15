const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("Part_1", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "Part_1", .module = mod },
        },
    });

    const env_raylib_path = b.graph.environ_map.get("RAYLIB_PATH");
    const default_raylib_path = if (target.result.os.tag == .windows) "C:\\raylib\\raylib\\src" else "/home/szp/raylib/raylib/src";
    const raylib_path = b.option([]const u8, "raylib-path", "Path to raylib headers and library") orelse env_raylib_path orelse default_raylib_path;
    root_mod.addIncludePath(.{ .cwd_relative = raylib_path });
    root_mod.addLibraryPath(.{ .cwd_relative = raylib_path });
    root_mod.linkSystemLibrary("raylib", .{ .use_pkg_config = .no, .preferred_link_mode = .static });

    const os_tag = target.result.os.tag;
    if (os_tag == .windows) {
        root_mod.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("gdi32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("opengl32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("winmm", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("shell32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("ole32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("advapi32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("comdlg32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("imm32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("version", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("ws2_32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("oleaut32", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("uuid", .{ .use_pkg_config = .no });
    } else if (os_tag == .linux) {
        root_mod.linkSystemLibrary("m", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("pthread", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("dl", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("rt", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("GL", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("X11", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("Xrandr", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("Xi", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("Xxf86vm", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("Xinerama", .{ .use_pkg_config = .no });
        root_mod.linkSystemLibrary("Xcursor", .{ .use_pkg_config = .no });
    }

    const exe = b.addExecutable(.{
        .name = "Part_1",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
