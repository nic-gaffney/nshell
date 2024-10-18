const std = @import("std");
const c = @cImport({
    @cInclude("glob.h");
});

pub fn main() !void {
    var args = std.process.args();
    const shellname = args.next().?;
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    defer stdin.close();
    defer stdout.close();

    var writer = stdout.writer();
    var reader = stdin.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    _ = try writer.write("> ");
    while ((try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024))) |buf| {
        const input = try parseCommand(allocator, buf);
        defer allocator.free(input);
        if (!try customCommand(input))
            _ = runCommand(allocator, input) catch |err| {
                _ = try writer.print("{s}: {any}\n", .{ shellname, err });
            };
        _ = try writer.write("> ");
    }
    _ = try writer.write("\nexit\n");
}

fn parseCommand(allocator: std.mem.Allocator, buf: []u8) ![][]const u8 {
    var splitIter = std.mem.splitAny(u8, buf, std.ascii.whitespace ++ &[_]u8{0});
    var args = std.ArrayList([]const u8).init(allocator);
    while (splitIter.next()) |arg| {
        if (arg.len == 0) continue;
        try args.append(arg);
    }
    return args.toOwnedSlice();
}

fn runCommand(allocator: std.mem.Allocator, input: []const []const u8) !std.process.Child.Term {
    var child = std.process.Child.init(input, allocator);
    return child.spawnAndWait();
}

fn customCommand(input: []const []const u8) !bool {
    if (input.len == 0) return false;
    if (std.mem.eql(u8, input[0], "exit")) std.process.exit(0);
    if (std.mem.eql(u8, input[0], "cd")) {
        try cd(if (input.len > 1) input[1] else "");
        return true;
    }
    return false;
}

fn cd(buf: []const u8) !void {
    if (buf.len == 0) {
        var globbuf: c.glob_t = undefined;
        _ = c.glob("~", c.GLOB_TILDE | c.GLOB_ONLYDIR | c.GLOB_NOSORT, null, &globbuf);
        try std.process.changeCurDir(std.mem.span(globbuf.gl_pathv[0]));
        return;
    }
    var dir: std.fs.Dir = std.fs.cwd().openDir(buf, .{}) catch |err| {
        var stdout = std.io.getStdOut();
        try stdout.writer().print("cd: {any}\n", .{err});
        return;
    };
    defer dir.close();
    try dir.setAsCwd();
}
