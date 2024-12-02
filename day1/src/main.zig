const std = @import("std");
const helpers = @import("helpers.zig");

/// Simple associative array structure
const associative_array = struct {
    a: std.ArrayList(i64),
    b: std.ArrayList(i64),
};

/// Map iteration function for operating across a file.
fn iter(ctx: *helpers.Context, line: []const u8) void {
    var aa: *associative_array = @alignCast(@ptrCast(ctx.data));
    var it = std.mem.split(u8, line, " ");
    var idx: u8 = 0;
    while (it.next()) |num| {
        const val = std.fmt.parseInt(i64, num, 10) catch {
            idx += 1;
            continue;
        };
        if (idx == 0) {
            aa.a.append(val) catch unreachable;
        } else {
            aa.b.append(val) catch unreachable;
        }
        idx += 1;
    }
}

pub fn main() !void {
    var alloc = std.heap.page_allocator;
    var aa: associative_array = associative_array{
        .a = std.ArrayList(i64).init(alloc),
        .b = std.ArrayList(i64).init(alloc),
    };
    var ctx: helpers.Context = helpers.Context{
        .data = @ptrCast(&aa),
    };
    const filename = try helpers.grab_file_arg(alloc);
    defer alloc.free(filename);
    try helpers.iterate_file(std.heap.page_allocator, filename, iter, &ctx);
    const data_a = try aa.a.toOwnedSlice();
    const data_b = try aa.b.toOwnedSlice();
    defer alloc.free(data_a);
    defer alloc.free(data_b);

    // part 1
    std.mem.sort(i64, data_a, {}, comptime std.sort.asc(i64));
    std.mem.sort(i64, data_b, {}, comptime std.sort.asc(i64));
    var idx: usize = 0;
    var sum: i64 = 0;
    var map = std.AutoHashMap(i64, i64).init(alloc);
    defer map.deinit();
    while (idx < data_a.len) : (idx += 1) {
        const num = data_b[idx];
        // part 1 stuff
        sum += helpers.abs(i64, data_a[idx] - num);

        // go ahead and get the counts for part 2
        const entry = map.get(num);
        if (entry) |val| {
            try map.put(num, val + 1);
        } else {
            try map.put(num, 1);
        }
    }
    std.debug.print("part 1 = {d}\n", .{sum});

    // part 2
    sum = 0;
    for (data_a) |num| {
        const entry = map.get(num);
        if (entry) |val| {
            sum += (num * val);
        }
    }
    std.debug.print("part 2 = {d}\n", .{sum});
}
