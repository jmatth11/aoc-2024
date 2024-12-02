const std = @import("std");
const helpers = @import("helpers.zig");

const Direction = enum {
    down,
    up,
    same,

    pub fn eval(comptime T: type, a: T, b: T) Direction {
        const op = a - b;
        if (op < 0) return Direction.down;
        if (op > 0) return Direction.up;
        return Direction.same;
    }
};

const Report = struct {
    safe: bool = true,
    steps: []i64,
    direction: ?Direction = null,
};

const ReportCount = struct {
    alloc: std.mem.Allocator,
    safe_count: u64 = 0,
    reports: std.ArrayList(Report),
};

fn same_direction(comptime T: type, ref: Direction, a: T, b: T) bool {
    const dir = Direction.eval(T, a, b);
    return ref == dir;
}

fn safe_distance(comptime T: type, a: T, b: T) bool {
    const op = helpers.abs(T, a - b);
    if (op > 0 and op < 4) return true;
    return false;
}

/// Map iteration function for operating across a file.
fn iter(ctx: *helpers.Context, line: []const u8) void {
    var report_count: *ReportCount = @alignCast(@ptrCast(ctx.data));
    var it = std.mem.split(u8, line, " ");
    var rep = Report{
        .steps = undefined,
    };
    var prev_val: ?i64 = null;
    var steps = std.ArrayList(i64).init(report_count.alloc);
    while (it.next()) |num| {
        const val = std.fmt.parseInt(i64, num, 10) catch {
            continue;
        };
        var reject = false;
        if (prev_val == null) {} else if (rep.direction == null) {
            const dir = Direction.eval(i64, prev_val.?, val);
            const safe = safe_distance(i64, prev_val.?, val);
            if (dir != Direction.same and safe) {
                rep.direction = dir;
            } else {
                reject = true;
            }
        } else {
            const same = same_direction(i64, rep.direction.?, prev_val.?, val);
            const safe = safe_distance(i64, prev_val.?, val);
            reject = !same or !safe;
        }
        if (reject) {
            rep.safe = false;
        }
        prev_val = val;
        steps.append(val) catch unreachable;
    }
    if (rep.safe) {
        report_count.safe_count += 1;
    }
    rep.steps = steps.toOwnedSlice() catch unreachable;
    report_count.reports.append(rep) catch unreachable;
}

fn part2(report_count: *ReportCount) !void {
    for (report_count.reports.items) |rep| {
        var new_rep = Report{
            .steps = undefined,
        };
        var dampend: bool = false;
        var idx: usize = 0;
        while (idx < rep.steps.len) : (idx += 1) {
            if (idx == 0) continue;
            if (new_rep.direction == null) {
                const dir = Direction.eval(i64, rep.steps[idx - 1], rep.steps[idx]);
                if (dir != Direction.same) {
                    new_rep.direction = dir;
                }
            }
            var same = false;
            if (new_rep.direction) |dir| {
                same = same_direction(i64, dir, rep.steps[idx - 1], rep.steps[idx]);
            }
            const safe = safe_distance(i64, rep.steps[idx - 1], rep.steps[idx]);
            if (!same or !safe) {
                if (dampend) {
                    new_rep.safe = false;
                } else {
                    if (!same) {
                        if (idx > 1) {
                            const new_dir = Direction.eval(i64, rep.steps[idx - 2], rep.steps[idx]);
                            // TODO not sure if I need to do anything here
                            if (new_dir != Direction.same and new_dir == new_rep.direction) {}
                        }
                        if (idx == 2 and (idx + 1) < rep.steps.len) {
                            const cur_dir = Direction.eval(i64, rep.steps[idx - 1], rep.steps[idx]);
                            const next_dir = Direction.eval(i64, rep.steps[idx], rep.steps[idx + 1]);
                            if (cur_dir == next_dir and cur_dir != Direction.same) {
                                new_rep.direction = cur_dir;
                            }
                        }
                    }
                    if (!safe) {
                        if (idx > 1) {
                            const new_safe = safe_distance(i64, rep.steps[idx - 2], rep.steps[idx]);
                            if (new_safe) idx += 1;
                        } else if (idx == 2 and (idx + 1) < rep.steps.len) {}
                    }
                    dampend = true;
                }
            }
        }
        if (new_rep.safe) {
            report_count.safe_count += 1;
        }
    }
}

pub fn main() !void {
    var alloc = std.heap.page_allocator;
    var count = ReportCount{
        .alloc = alloc,
        .reports = std.ArrayList(Report).init(alloc),
    };
    var ctx: helpers.Context = helpers.Context{
        .data = @ptrCast(&count),
    };
    const filename = try helpers.grab_file_arg(alloc);
    defer alloc.free(filename);
    try helpers.iterate_file(std.heap.page_allocator, filename, iter, &ctx);

    // part 1
    std.debug.print("part 1 = {d}\n", .{count.safe_count});

    // part 2
    count.safe_count = 0;
    try part2(&count);

    std.debug.print("part 2 = {d}\n", .{count.safe_count});
}
