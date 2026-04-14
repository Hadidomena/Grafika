const std = @import("std");
const Io = std.Io;

const Part_1 = @import("root.zig");

const c = @cImport({
    @cInclude("raylib.h");
});

const Point3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

const Edge = struct {
    a: Point3,
    b: Point3,
};

fn isNumberChar(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '-' or ch == '+' or ch == '.' or ch == 'e' or ch == 'E';
}

fn parseEdges(allocator: std.mem.Allocator, path: []const u8) !std.ArrayList(Edge) {
    var list: std.ArrayList(Edge) = .empty;

    var path_c = try allocator.alloc(u8, path.len + 1);
    var pi: usize = 0;
    while (pi < path.len) : (pi += 1) path_c[pi] = path[pi];
    path_c[path.len] = 0;
    const raw = c.LoadFileText(&path_c[0]);
    if (raw == null) {
        allocator.free(path_c);
        return error.FileNotFound;
    }
    var len: usize = 0;
    while (raw[len] != 0) len += 1;
    const contents = raw[0..len];
    allocator.free(path_c);

    var pos: usize = 0;
    while (pos < contents.len) {
        var nums: [6]f32 = .{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
        var count: usize = 0;

        while (pos < contents.len and count < nums.len) {
            while (pos < contents.len and !isNumberChar(@as(u8, contents[pos]))) pos += 1;
            if (pos >= contents.len) break;
            const start = pos;
            pos += 1;
            while (pos < contents.len and isNumberChar(@as(u8, contents[pos]))) pos += 1;
            const tok_len = pos - start;
            var tmp: [64]u8 = undefined;
            if (tok_len >= tmp.len) return error.FileNotFound;
            var ti: usize = 0;
            while (ti < tok_len) : (ti += 1) tmp[ti] = @as(u8, contents[start + ti]);
            const tok = tmp[0..tok_len];
            const val = try std.fmt.parseFloat(f32, tok);
            nums[count] = val;
            count += 1;
        }

        if (count == nums.len) {
            const e = Edge{ .a = Point3{ .x = nums[0], .y = nums[1], .z = nums[2] }, .b = Point3{ .x = nums[3], .y = nums[4], .z = nums[5] } };
            try list.append(allocator, e);
        }

        while (pos < contents.len and contents[pos] != '\n') pos += 1;
        if (pos < contents.len and contents[pos] == '\n') pos += 1;
    }

    c.UnloadFileText(raw);

    return list;
}

fn runRenderer(edges_slice: []const Edge) void {
    c.InitWindow(800, 600, "Edge Viewer");
    c.SetTargetFPS(60);
    const move_speed: f32 = 0.2;

    var camera: c.Camera3D = .{};
    camera.position = c.Vector3{ .x = 10.0, .y = 10.0, .z = 10.0 };
    camera.target = c.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    camera.up = c.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
    camera.fovy = 45.0;
    camera.projection = c.CAMERA_PERSPECTIVE;

    while (!c.WindowShouldClose()) {
        if (c.IsKeyDown(c.KEY_LEFT)) {
            camera.position.x -= move_speed;
            camera.target.x -= move_speed;
        }
        if (c.IsKeyDown(c.KEY_RIGHT)) {
            camera.position.x += move_speed;
            camera.target.x += move_speed;
        }
        if (c.IsKeyDown(c.KEY_UP)) {
            camera.position.z -= move_speed;
            camera.target.z -= move_speed;
        }
        if (c.IsKeyDown(c.KEY_DOWN)) {
            camera.position.z += move_speed;
            camera.target.z += move_speed;
        }

        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        c.BeginMode3D(camera);
        for (edges_slice) |edge| {
            const a = edge.a;
            const b = edge.b;
            const va = c.Vector3{ .x = a.x, .y = a.y, .z = a.z };
            const vb = c.Vector3{ .x = b.x, .y = b.y, .z = b.z };
            c.DrawLine3D(va, vb, c.BLACK);
        }
        c.EndMode3D();

        c.DrawText("Edge Viewer (ESC to close)", 10, 10, 20, c.DARKGRAY);

        c.EndDrawing();
    }

    c.CloseWindow();
}

pub fn main(init: std.process.Init) !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var edges_list: std.ArrayList(Edge) = .empty;
    var edges_slice: []const Edge = &[_]Edge{};

    if (args.len > 1) {
        const path = args[1];
        edges_list = try parseEdges(arena, path);
        edges_slice = edges_list.items;
    } else {
        try edges_list.append(arena, Edge{ .a = Point3{ .x = -1, .y = -1, .z = -1 }, .b = Point3{ .x = 1, .y = -1, .z = -1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = 1, .y = -1, .z = -1 }, .b = Point3{ .x = 1, .y = 1, .z = -1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = 1, .y = 1, .z = -1 }, .b = Point3{ .x = -1, .y = 1, .z = -1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = -1, .y = 1, .z = -1 }, .b = Point3{ .x = -1, .y = -1, .z = -1 } });

        try edges_list.append(arena, Edge{ .a = Point3{ .x = -1, .y = -1, .z = 1 }, .b = Point3{ .x = 1, .y = -1, .z = 1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = 1, .y = -1, .z = 1 }, .b = Point3{ .x = 1, .y = 1, .z = 1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = 1, .y = 1, .z = 1 }, .b = Point3{ .x = -1, .y = 1, .z = 1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = -1, .y = 1, .z = 1 }, .b = Point3{ .x = -1, .y = -1, .z = 1 } });

        try edges_list.append(arena, Edge{ .a = Point3{ .x = -1, .y = -1, .z = -1 }, .b = Point3{ .x = -1, .y = -1, .z = 1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = 1, .y = -1, .z = -1 }, .b = Point3{ .x = 1, .y = -1, .z = 1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = 1, .y = 1, .z = -1 }, .b = Point3{ .x = 1, .y = 1, .z = 1 } });
        try edges_list.append(arena, Edge{ .a = Point3{ .x = -1, .y = 1, .z = -1 }, .b = Point3{ .x = -1, .y = 1, .z = 1 } });

        edges_slice = edges_list.items;
    }

    runRenderer(edges_slice);

    edges_list.deinit(arena);
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

test "raylib integration - gen image (CPU)" {
    const img = c.GenImageColor(2, 2, c.RAYWHITE);
    try std.testing.expect(c.IsImageValid(img));
    c.UnloadImage(img);
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
