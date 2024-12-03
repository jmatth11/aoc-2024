const std = @import("std");
const helpers = @import("helpers.zig");

fn print_steps(rep: Report, safe: bool) void {
    for (rep.steps) |s| {
        std.debug.print("{d},", .{s});
    }
    std.debug.print(" {}\n", .{safe});
}

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
    return op > 0 and op < 4;
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
            reject = dir == Direction.same or !safe;
            rep.direction = dir;
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
            if (same and safe) continue;
            if (dampend) {
                new_rep.safe = false;
            } else {
                var double_error = false;
                if (idx > 1) {
                    const prev_same = same_direction(
                        i64,
                        new_rep.direction.?,
                        rep.steps[idx - 2],
                        rep.steps[idx],
                    );
                    const prev_safe = safe_distance(
                        i64,
                        rep.steps[idx - 2],
                        rep.steps[idx],
                    );
                    if ((!prev_same or !prev_safe) and (idx + 1) < rep.steps.len) {
                        var handled = false;
                        // this is a special case where the first element gives us the wrong direction
                        // but by removing the first element all the rest are correct.
                        if (idx == 2 and safe) {
                            const cur_dir = Direction.eval(i64, rep.steps[idx - 1], rep.steps[idx]);
                            const next_dir = Direction.eval(i64, rep.steps[idx], rep.steps[idx + 1]);
                            if (cur_dir == next_dir and cur_dir != Direction.same) {
                                new_rep.direction = cur_dir;
                                handled = true;
                            }
                        }
                        if (!handled) {
                            const skip_same = same_direction(
                                i64,
                                new_rep.direction.?,
                                rep.steps[idx - 1],
                                rep.steps[idx + 1],
                            );
                            const skip_safe = safe_distance(
                                i64,
                                rep.steps[idx - 1],
                                rep.steps[idx + 1],
                            );
                            // this will skip 2 elements
                            if (skip_same and skip_safe) {
                                idx += 1;
                            } else {
                                double_error = true;
                            }
                        }
                    }
                } else {
                    const skip_dir = Direction.eval(i64, rep.steps[idx - 1], rep.steps[idx + 1]);
                    const skip_safe = safe_distance(i64, rep.steps[idx - 1], rep.steps[idx + 1]);
                    if (skip_dir != Direction.same and skip_safe) {
                        idx += 1;
                        new_rep.direction = skip_dir;
                    } else {
                        const next_dir = Direction.eval(i64, rep.steps[idx], rep.steps[idx + 1]);
                        const next_safe = safe_distance(i64, rep.steps[idx], rep.steps[idx + 1]);
                        if (next_dir != Direction.same and next_safe) {
                            new_rep.direction = next_dir;
                            // since we already do the comparison of the next
                            // iteration, we can skip ahead
                            idx += 1;
                        } else {
                            double_error = true;
                        }
                    }
                }
                dampend = true;
                if (double_error) {
                    new_rep.safe = false;
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
