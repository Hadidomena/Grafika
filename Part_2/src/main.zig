const std = @import("std");
const c = @import("raylib");

// Types

const Vec3 = struct { x: f32, y: f32, z: f32 };

const Face = struct { a: Vec3, b: Vec3, c: Vec3, d: Vec3 };

const Camera = struct {
    pos: Vec3 = .{ .x = 0, .y = 0, .z = -8 },
    yaw: f32 = 0,
    pitch: f32 = 0,
    focal: f32 = 520,
};

const Px = struct { x: i32, y: i32 };

const DrawFace = struct {
    p: [4]Px,
    depth: f32,
};

const CulledFace = struct {
    p: [4]Px,
    reason: enum { backface, near, offscreen },
};

// Math helpers

fn sub(a: Vec3, b: Vec3) Vec3 {
    return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
}
fn cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}
fn dot(a: Vec3, b: Vec3) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

// Camera transform

fn toCam(p: Vec3, cam: Camera) Vec3 {
    const dx = p.x - cam.pos.x;
    const dy = p.y - cam.pos.y;
    const dz = p.z - cam.pos.z;
    const cy = @cos(cam.yaw);
    const sy = @sin(cam.yaw);
    const x1 = dx * cy - dz * sy;
    const z1 = dx * sy + dz * cy;
    const cp = @cos(cam.pitch);
    const sp = @sin(cam.pitch);
    return .{ .x = x1, .y = dy * cp - z1 * sp, .z = dy * sp + z1 * cp };
}

const SW: i32 = 800;
const SH: i32 = 600;
const NEAR: f32 = 0.05;

fn project(p: Vec3, focal: f32) ?Px {
    if (p.z <= NEAR) return null;
    return .{
        .x = @intFromFloat(@as(f32, SW) * 0.5 + focal * p.x / p.z),
        .y = @intFromFloat(@as(f32, SH) * 0.5 - focal * p.y / p.z),
    };
}

fn pv(p: Px) c.Vector2 {
    return .{ .x = @floatFromInt(p.x), .y = @floatFromInt(p.y) };
}

// Geometry builders

fn addBoxFaces(
    list: *std.ArrayList(Face),
    alloc: std.mem.Allocator,
    center: Vec3,
    size: Vec3,
) !void {
    const hx = size.x * 0.5;
    const hy = size.y * 0.5;
    const hz = size.z * 0.5;
    const p = [8]Vec3{
        .{ .x = center.x - hx, .y = center.y - hy, .z = center.z - hz }, // 0
        .{ .x = center.x + hx, .y = center.y - hy, .z = center.z - hz }, // 1
        .{ .x = center.x + hx, .y = center.y + hy, .z = center.z - hz }, // 2
        .{ .x = center.x - hx, .y = center.y + hy, .z = center.z - hz }, // 3
        .{ .x = center.x - hx, .y = center.y - hy, .z = center.z + hz }, // 4
        .{ .x = center.x + hx, .y = center.y - hy, .z = center.z + hz }, // 5
        .{ .x = center.x + hx, .y = center.y + hy, .z = center.z + hz }, // 6
        .{ .x = center.x - hx, .y = center.y + hy, .z = center.z + hz }, // 7
    };
    try list.append(alloc, .{ .a = p[0], .b = p[3], .c = p[2], .d = p[1] }); // front  -Z
    try list.append(alloc, .{ .a = p[4], .b = p[5], .c = p[6], .d = p[7] }); // back   +Z
    try list.append(alloc, .{ .a = p[3], .b = p[7], .c = p[6], .d = p[2] }); // top    +Y
    try list.append(alloc, .{ .a = p[0], .b = p[1], .c = p[5], .d = p[4] }); // bottom -Y
    try list.append(alloc, .{ .a = p[0], .b = p[4], .c = p[7], .d = p[3] }); // left   -X
    try list.append(alloc, .{ .a = p[1], .b = p[2], .c = p[6], .d = p[5] }); // right  +X
}

fn isNumChar(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or ch == '-' or ch == '+' or ch == '.' or ch == 'e' or ch == 'E';
}

fn parseBoxFile(alloc: std.mem.Allocator, path: []const u8) !std.ArrayList(Face) {
    var list: std.ArrayList(Face) = .empty;

    const pathz = try alloc.alloc(u8, path.len + 1);
    @memcpy(pathz[0..path.len], path);
    pathz[path.len] = 0;
    const raw = c.LoadFileText(&pathz[0]);
    alloc.free(pathz);
    if (raw == null) return error.FileNotFound;
    var len: usize = 0;
    while (raw[len] != 0) len += 1;
    const text = raw[0..len];
    defer c.UnloadFileText(raw);

    var pos: usize = 0;
    while (pos < text.len) {
        var nums: [6]f32 = undefined;
        var count: usize = 0;
        while (pos < text.len and count < 6) {
            while (pos < text.len and !isNumChar(text[pos])) pos += 1;
            if (pos >= text.len) break;
            const start = pos;
            pos += 1;
            while (pos < text.len and isNumChar(text[pos])) pos += 1;
            const tok = text[start..pos];
            var tmp: [64]u8 = undefined;
            if (tok.len >= tmp.len) return error.TokenTooLong;
            @memcpy(tmp[0..tok.len], tok);
            nums[count] = try std.fmt.parseFloat(f32, tmp[0..tok.len]);
            count += 1;
        }
        if (count == 6) {
            const p0 = Vec3{ .x = nums[0], .y = nums[1], .z = nums[2] };
            const p1 = Vec3{ .x = nums[3], .y = nums[4], .z = nums[5] };
            const ctr = Vec3{
                .x = (p0.x + p1.x) * 0.5,
                .y = (p0.y + p1.y) * 0.5,
                .z = (p0.z + p1.z) * 0.5,
            };
            const sz = Vec3{
                .x = @abs(p1.x - p0.x),
                .y = @abs(p1.y - p0.y),
                .z = @abs(p1.z - p0.z),
            };
            try addBoxFaces(&list, alloc, ctr, sz);
        }
        while (pos < text.len and text[pos] != '\n') pos += 1;
        if (pos < text.len) pos += 1;
    }
    return list;
}

// Painter sort (insertion sort, descending centroid)

fn sortDesc(faces: []DrawFace) void {
    var i: usize = 1;
    while (i < faces.len) : (i += 1) {
        const key = faces[i];
        var j = i;
        while (j > 0 and faces[j - 1].depth < key.depth) : (j -= 1) {
            faces[j] = faces[j - 1];
        }
        faces[j] = key;
    }
}

fn drawQuadOutline(p: [4]Px, col: c.Color) void {
    c.DrawLineV(pv(p[0]), pv(p[1]), col);
    c.DrawLineV(pv(p[1]), pv(p[2]), col);
    c.DrawLineV(pv(p[2]), pv(p[3]), col);
    c.DrawLineV(pv(p[3]), pv(p[0]), col);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);

    var faces: std.ArrayList(Face) = .empty;
    if (args.len >= 3 and std.mem.eql(u8, args[1], "--boxes")) {
        faces = try parseBoxFile(alloc, args[2]);
    } else {
        const sz = Vec3{ .x = 1.8, .y = 1.8, .z = 1.8 };
        try addBoxFaces(&faces, alloc, .{ .x = -3.2, .y = 0, .z = 0 }, sz);
        try addBoxFaces(&faces, alloc, .{ .x = 3.2, .y = 0, .z = 0 }, sz);
        try addBoxFaces(&faces, alloc, .{ .x = 0, .y = 0, .z = -3.2 }, sz);
        try addBoxFaces(&faces, alloc, .{ .x = 0, .y = 0, .z = 3.2 }, sz);
    }
    defer faces.deinit(alloc);

    c.InitWindow(SW, SH, "Virtual Camera – painter's algorithm");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    const FILL = c.Color{ .r = 196, .g = 212, .b = 226, .a = 255 };
    const COL_BACKFACE = c.Color{ .r = 220, .g = 50, .b = 50, .a = 220 }; // red
    const COL_NEAR = c.Color{ .r = 255, .g = 140, .b = 0, .a = 220 }; // orange
    const COL_OFFSCREEN = c.Color{ .r = 160, .g = 0, .b = 200, .a = 220 }; // purple

    const MOVE: f32 = 0.15;
    const TURN: f32 = 0.03;
    const FSTEP: f32 = 3.5;

    var cam = Camera{};
    var debug_mode = false;

    var draw_buf: std.ArrayList(DrawFace) = .empty;
    var culled_buf: std.ArrayList(CulledFace) = .empty;
    defer draw_buf.deinit(alloc);
    defer culled_buf.deinit(alloc);

    while (!c.WindowShouldClose()) {
        if (c.IsKeyPressed(c.KEY_TAB)) debug_mode = !debug_mode;
        if (c.IsKeyDown(c.KEY_LEFT)) cam.yaw -= TURN;
        if (c.IsKeyDown(c.KEY_RIGHT)) cam.yaw += TURN;
        if (c.IsKeyDown(c.KEY_UP)) cam.pitch += TURN;
        if (c.IsKeyDown(c.KEY_DOWN)) cam.pitch -= TURN;
        cam.pitch = std.math.clamp(cam.pitch, -1.4, 1.4);

        const fx = @sin(cam.yaw);
        const fz = @cos(cam.yaw);
        const rx = @cos(cam.yaw);
        const rz = -@sin(cam.yaw);
        if (c.IsKeyDown(c.KEY_W)) {
            cam.pos.x += fx * MOVE;
            cam.pos.z += fz * MOVE;
        }
        if (c.IsKeyDown(c.KEY_S)) {
            cam.pos.x -= fx * MOVE;
            cam.pos.z -= fz * MOVE;
        }
        if (c.IsKeyDown(c.KEY_A)) {
            cam.pos.x -= rx * MOVE;
            cam.pos.z -= rz * MOVE;
        }
        if (c.IsKeyDown(c.KEY_D)) {
            cam.pos.x += rx * MOVE;
            cam.pos.z += rz * MOVE;
        }
        if (c.IsKeyDown(c.KEY_Q)) cam.pos.y += MOVE;
        if (c.IsKeyDown(c.KEY_E)) cam.pos.y -= MOVE;
        if (c.IsKeyDown(c.KEY_Z)) cam.focal -= FSTEP;
        if (c.IsKeyDown(c.KEY_X)) cam.focal += FSTEP;
        cam.focal = std.math.clamp(cam.focal, 80, 1200);

        draw_buf.clearRetainingCapacity();
        culled_buf.clearRetainingCapacity();

        var n_backface: usize = 0;
        var n_near: usize = 0;
        var n_offscreen: usize = 0;

        for (faces.items) |face| {
            const ac = toCam(face.a, cam);
            const bc = toCam(face.b, cam);
            const cc = toCam(face.c, cam);
            const dc = toCam(face.d, cam);

            if (ac.z <= NEAR or bc.z <= NEAR or cc.z <= NEAR or dc.z <= NEAR) {
                n_near += 1;
                if (debug_mode) {
                    const safe = NEAR + 0.01;
                    const qa = if (ac.z > NEAR) ac else Vec3{ .x = ac.x, .y = ac.y, .z = safe };
                    const qb = if (bc.z > NEAR) bc else Vec3{ .x = bc.x, .y = bc.y, .z = safe };
                    const qc = if (cc.z > NEAR) cc else Vec3{ .x = cc.x, .y = cc.y, .z = safe };
                    const qd = if (dc.z > NEAR) dc else Vec3{ .x = dc.x, .y = dc.y, .z = safe };
                    const pa = project(qa, cam.focal) orelse continue;
                    const pb = project(qb, cam.focal) orelse continue;
                    const pc = project(qc, cam.focal) orelse continue;
                    const pd = project(qd, cam.focal) orelse continue;
                    culled_buf.append(alloc, .{ .p = .{ pa, pb, pc, pd }, .reason = .near }) catch {};
                }
                continue;
            }

            const normal = cross(sub(bc, ac), sub(cc, ac));
            const ctr = Vec3{
                .x = (ac.x + bc.x + cc.x + dc.x) * 0.25,
                .y = (ac.y + bc.y + cc.y + dc.y) * 0.25,
                .z = (ac.z + bc.z + cc.z + dc.z) * 0.25,
            };
            if (dot(normal, ctr) >= 0) {
                n_backface += 1;
                if (debug_mode) {
                    const pa = project(ac, cam.focal) orelse continue;
                    const pb = project(bc, cam.focal) orelse continue;
                    const pc = project(cc, cam.focal) orelse continue;
                    const pd = project(dc, cam.focal) orelse continue;
                    culled_buf.append(alloc, .{ .p = .{ pa, pb, pc, pd }, .reason = .backface }) catch {};
                }
                continue;
            }

            const pa = project(ac, cam.focal) orelse continue;
            const pb = project(bc, cam.focal) orelse continue;
            const pc = project(cc, cam.focal) orelse continue;
            const pd = project(dc, cam.focal) orelse continue;

            // cull of offscreen faces
            const min_x = @min(@min(pa.x, pb.x), @min(pc.x, pd.x));
            const max_x = @max(@max(pa.x, pb.x), @max(pc.x, pd.x));
            const min_y = @min(@min(pa.y, pb.y), @min(pc.y, pd.y));
            const max_y = @max(@max(pa.y, pb.y), @max(pc.y, pd.y));
            if (max_x < 0 or min_x >= SW or max_y < 0 or min_y >= SH) {
                n_offscreen += 1;
                if (debug_mode) {
                    culled_buf.append(alloc, .{ .p = .{ pa, pb, pc, pd }, .reason = .offscreen }) catch {};
                }
                continue;
            }

            draw_buf.append(alloc, .{ .p = .{ pa, pb, pc, pd }, .depth = ctr.z }) catch continue;
        }

        sortDesc(draw_buf.items);

        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        for (draw_buf.items) |df| {
            const v1 = pv(df.p[0]);
            const v2 = pv(df.p[1]);
            const v3 = pv(df.p[2]);
            const v4 = pv(df.p[3]);
            c.DrawTriangle(v1, v3, v2, FILL);
            c.DrawTriangle(v1, v4, v3, FILL);
            c.DrawLineV(v1, v2, c.BLACK);
            c.DrawLineV(v2, v3, c.BLACK);
            c.DrawLineV(v3, v4, c.BLACK);
            c.DrawLineV(v4, v1, c.BLACK);
        }

        // Debug: culled faces as coloured wireframes drawn on top
        if (debug_mode) {
            for (culled_buf.items) |cf| {
                const col = switch (cf.reason) {
                    .backface => COL_BACKFACE,
                    .near => COL_NEAR,
                    .offscreen => COL_OFFSCREEN,
                };
                drawQuadOutline(cf.p, col);
            }
        }

        // HUD
        const total = faces.items.len;
        const drawn = draw_buf.items.len;
        const culled = total - drawn;

        c.DrawText("W/S/A/D move  Q/E up/down  Arrows rotate  Z/X focal  Tab debug", 10, 10, 15, c.DARKGRAY);

        var buf: [180]u8 = undefined;
        if (std.fmt.bufPrintZ(
            &buf,
            "pos({d:.1},{d:.1},{d:.1})  yaw:{d:.2}  pitch:{d:.2}  f:{d:.0}",
            .{ cam.pos.x, cam.pos.y, cam.pos.z, cam.yaw, cam.pitch, cam.focal },
        )) |txt| c.DrawText(txt, 10, 28, 15, c.GRAY) else |_| {}

        if (std.fmt.bufPrintZ(
            &buf,
            "faces total:{d}  drawn:{d}  culled:{d}  (back:{d} near:{d} offscreen:{d})",
            .{ total, drawn, culled, n_backface, n_near, n_offscreen },
        )) |txt| {
            c.DrawText(txt, 10, 46, 15, if (debug_mode) c.RED else c.DARKGRAY);
        } else |_| {}

        if (debug_mode) {
            c.DrawText("DEBUG  red=back-face  orange=near-clipped  purple=off-screen", 10, 64, 15, c.RED);
        }

        c.EndDrawing();
    }
}

test "box face count" {
    var list: std.ArrayList(Face) = .empty;
    defer list.deinit(std.testing.allocator);
    try addBoxFaces(&list, std.testing.allocator, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 1, .z = 1 });
    try std.testing.expectEqual(@as(usize, 6), list.items.len);
}
