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

const CameraState = struct {
    pos: Point3,
    yaw: f32,
    focal: f32,
};

const ProjectedPoint = struct {
    x: i32,
    y: i32,
    visible: bool,
};

fn worldToCamera(p: Point3, cam: CameraState) Point3 {
    const dx = p.x - cam.pos.x;
    const dy = p.y - cam.pos.y;
    const dz = p.z - cam.pos.z;
    const c_yaw = @cos(cam.yaw);
    const s_yaw = @sin(cam.yaw);

    return Point3{
        .x = dx * c_yaw - dz * s_yaw,
        .y = dy,
        .z = dx * s_yaw + dz * c_yaw,
    };
}

fn projectPoint(p_cam: Point3, width: i32, height: i32, focal: f32) ProjectedPoint {
    const near: f32 = 0.05;
    if (p_cam.z <= near) {
        return .{ .x = 0, .y = 0, .visible = false };
    }

    const cx = @as(f32, @floatFromInt(width)) * 0.5;
    const cy = @as(f32, @floatFromInt(height)) * 0.5;
    const sx = cx + focal * (p_cam.x / p_cam.z);
    const sy = cy - focal * (p_cam.y / p_cam.z);

    return .{
        .x = @intFromFloat(sx),
        .y = @intFromFloat(sy),
        .visible = true,
    };
}

fn addBoxEdges(list: *std.ArrayList(Edge), allocator: std.mem.Allocator, center: Point3, size: Point3) !void {
    const hx = size.x * 0.5;
    const hy = size.y * 0.5;
    const hz = size.z * 0.5;

    const p0 = Point3{ .x = center.x - hx, .y = center.y - hy, .z = center.z - hz };
    const p1 = Point3{ .x = center.x + hx, .y = center.y - hy, .z = center.z - hz };
    const p2 = Point3{ .x = center.x + hx, .y = center.y + hy, .z = center.z - hz };
    const p3 = Point3{ .x = center.x - hx, .y = center.y + hy, .z = center.z - hz };

    const p4 = Point3{ .x = center.x - hx, .y = center.y - hy, .z = center.z + hz };
    const p5 = Point3{ .x = center.x + hx, .y = center.y - hy, .z = center.z + hz };
    const p6 = Point3{ .x = center.x + hx, .y = center.y + hy, .z = center.z + hz };
    const p7 = Point3{ .x = center.x - hx, .y = center.y + hy, .z = center.z + hz };

    try list.append(allocator, .{ .a = p0, .b = p1 });
    try list.append(allocator, .{ .a = p1, .b = p2 });
    try list.append(allocator, .{ .a = p2, .b = p3 });
    try list.append(allocator, .{ .a = p3, .b = p0 });

    try list.append(allocator, .{ .a = p4, .b = p5 });
    try list.append(allocator, .{ .a = p5, .b = p6 });
    try list.append(allocator, .{ .a = p6, .b = p7 });
    try list.append(allocator, .{ .a = p7, .b = p4 });

    try list.append(allocator, .{ .a = p0, .b = p4 });
    try list.append(allocator, .{ .a = p1, .b = p5 });
    try list.append(allocator, .{ .a = p2, .b = p6 });
    try list.append(allocator, .{ .a = p3, .b = p7 });
}

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
    const screen_w = 800;
    const screen_h = 600;
    c.InitWindow(screen_w, screen_h, "Wirtualna Kamera - Wireframe");
    c.SetTargetFPS(60);
    const move_speed: f32 = 0.15;
    const turn_speed: f32 = 0.03;
    const focal_speed: f32 = 3.5;

    var camera = CameraState{
        .pos = Point3{ .x = 0.0, .y = 0.0, .z = -8.0 },
        .yaw = 0.0,
        .focal = 520.0,
    };

    while (!c.WindowShouldClose()) {
        if (c.IsKeyDown(c.KEY_LEFT)) {
            camera.yaw -= turn_speed;
        }
        if (c.IsKeyDown(c.KEY_RIGHT)) {
            camera.yaw += turn_speed;
        }

        const forward_x = @sin(camera.yaw);
        const forward_z = @cos(camera.yaw);
        const right_x = @cos(camera.yaw);
        const right_z = -@sin(camera.yaw);

        if (c.IsKeyDown(c.KEY_W)) {
            camera.pos.x += forward_x * move_speed;
            camera.pos.z += forward_z * move_speed;
        }
        if (c.IsKeyDown(c.KEY_S)) {
            camera.pos.x -= forward_x * move_speed;
            camera.pos.z -= forward_z * move_speed;
        }
        if (c.IsKeyDown(c.KEY_A)) {
            camera.pos.x -= right_x * move_speed;
            camera.pos.z -= right_z * move_speed;
        }
        if (c.IsKeyDown(c.KEY_D)) {
            camera.pos.x += right_x * move_speed;
            camera.pos.z += right_z * move_speed;
        }
        if (c.IsKeyDown(c.KEY_Q)) {
            camera.pos.y += move_speed;
        }
        if (c.IsKeyDown(c.KEY_E)) {
            camera.pos.y -= move_speed;
        }

        if (c.IsKeyDown(c.KEY_Z)) {
            camera.focal -= focal_speed;
        }
        if (c.IsKeyDown(c.KEY_X)) {
            camera.focal += focal_speed;
        }
        if (camera.focal < 80.0) {
            camera.focal = 80.0;
        }
        if (camera.focal > 1200.0) {
            camera.focal = 1200.0;
        }

        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        for (edges_slice) |edge| {
            const a_cam = worldToCamera(edge.a, camera);
            const b_cam = worldToCamera(edge.b, camera);
            const pa = projectPoint(a_cam, screen_w, screen_h, camera.focal);
            const pb = projectPoint(b_cam, screen_w, screen_h, camera.focal);

            if (pa.visible and pb.visible) {
                c.DrawLine(pa.x, pa.y, pb.x, pb.y, c.BLACK);
            }
        }

        c.DrawText("Sterowanie: W/S przod-tyl, A/D prawo-lewo, strzalki gora-dol i obrot, Z/X ogniskowa", 10, 10, 16, c.DARKGRAY);
        var info_buf: [128]u8 = undefined;
        const info = std.fmt.bufPrintZ(
            &info_buf,
            "Cam: ({d:.2}, {d:.2}, {d:.2}) yaw:{d:.2} f:{d:.1}",
            .{ camera.pos.x, camera.pos.y, camera.pos.z, camera.yaw, camera.focal },
        ) catch null;
        if (info) |text| c.DrawText(text, 10, 34, 16, c.GRAY);

        c.EndDrawing();
    }

    c.CloseWindow();
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var edges_list: std.ArrayList(Edge) = .empty;
    var edges_slice: []const Edge = &[_]Edge{};

    if (args.len > 1) {
        const path = args[1];
        edges_list = try parseEdges(arena, path);
        edges_slice = edges_list.items;
    } else {
        const box_size = Point3{ .x = 1.8, .y = 1.8, .z = 1.8 };
        try addBoxEdges(&edges_list, arena, Point3{ .x = -3.2, .y = 0.0, .z = 0.0 }, box_size);
        try addBoxEdges(&edges_list, arena, Point3{ .x = 3.2, .y = 0.0, .z = 0.0 }, box_size);
        try addBoxEdges(&edges_list, arena, Point3{ .x = 0.0, .y = 0.0, .z = -3.2 }, box_size);
        try addBoxEdges(&edges_list, arena, Point3{ .x = 0.0, .y = 0.0, .z = 3.2 }, box_size);

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
