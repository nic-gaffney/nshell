const std = @import("std");

pub fn build(b: *std.Build) void {
    const opt = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .optimize = opt,
        .target = target,
        .root_source_file = b.path("src/main.zig"),
        .name = "shell",
    });

    exe.linkLibC();
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args|
        run.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run.step);
}
